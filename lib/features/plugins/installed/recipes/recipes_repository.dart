import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../../../storage/storage_guard.dart';
import '../../../../sync/sync_service.dart';
import 'data/recipes_api.dart';
import 'recipes_models.dart';

/// Downscales an arbitrary image to a web-friendly JPEG. Runs in an isolate
/// (via [compute]) so decoding a large photo never janks the UI. Longest side
/// is capped so uploads/thumbnails stay small; quality 82 is a good balance.
Uint8List _processImage(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return raw;
  const maxDim = 1200;
  img.Image out = decoded;
  if (decoded.width > maxDim || decoded.height > maxDim) {
    out = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxDim)
        : img.copyResize(decoded, height: maxDim);
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: 82));
}

/// Orchestrates the Recipes plugin. Local ("Private") recipes and the set of
/// favourited items live in a single local-first JSON file; the shared
/// ("Public") catalogue, its reviews and photos are fetched from — and
/// published to — the sync server through [RecipeApi], tracking the signed-in
/// session the same way the chat plugin does. A [ChangeNotifier] so the page
/// rebuilds on any change.
class RecipesController extends ChangeNotifier {
  RecipesController(this._sync);

  final SyncService _sync;

  // ---- Local state --------------------------------------------------------

  final List<LocalRecipe> _local = [];
  final Set<String> _favoritePublicIds = {};
  bool _loadedLocal = false;

  // ---- Server state -------------------------------------------------------

  List<PublicRecipe> _public = [];
  bool _loadingPublic = false;
  String? _publicError;

  RecipeApi? _api;
  String? _apiServerUrl;
  String? _apiToken;

  // ---- Photo cache --------------------------------------------------------

  final Map<String, Uint8List?> _photoCache = {};
  final Set<String> _photoInFlight = {};

  File? _storeFile;

  // ---- Public getters -----------------------------------------------------

  bool get signedIn => _sync.signedIn;
  bool get loadingPublic => _loadingPublic;
  String? get publicError => _publicError;

  List<LocalRecipe> get privateRecipes {
    final list = List<LocalRecipe>.of(_local)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<PublicRecipe> get publicRecipes => List.unmodifiable(_public);

  /// Favourited local recipes plus favourited public recipes currently loaded.
  List<Object> get favouriteRecipes {
    final favLocal = _local.where((r) => r.isFavorite).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final favPublic =
        _public.where((r) => _favoritePublicIds.contains(r.id)).toList()
          ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return [...favLocal, ...favPublic];
  }

  bool isFavoritePublic(String id) => _favoritePublicIds.contains(id);

  /// The local ("Private") copy of a published recipe, if this user is the
  /// author and still has it — lets the Public tab route "edit" back to the
  /// authoritative local recipe.
  LocalRecipe? localByPublicId(String publicId) {
    for (final r in _local) {
      if (r.publicId == publicId) return r;
    }
    return null;
  }

  /// Removes a published recipe from the catalogue given its server id. Keeps
  /// the local copy (clearing its `publicId`) when one exists.
  Future<String?> unpublishByPublicId(String publicId) async {
    final local = localByPublicId(publicId);
    if (local != null) return unpublish(local.id);
    final api = _api;
    if (api == null) return 'Sign in to manage published recipes.';
    try {
      await api.deleteRecipe(publicId);
      await refreshPublic();
      return null;
    } on RecipeApiException catch (e) {
      return e.isNotFound ? null : e.message;
    } catch (e) {
      return '$e';
    }
  }

  int get favouriteCount =>
      _local.where((r) => r.isFavorite).length +
      _public.where((r) => _favoritePublicIds.contains(r.id)).length;

  // ---- Lifecycle ----------------------------------------------------------

  Future<void> init() async {
    await _load();
    _sync.addListener(_onSyncChanged);
    _onSyncChanged();
  }

  @override
  void dispose() {
    _sync.removeListener(_onSyncChanged);
    _api?.close();
    super.dispose();
  }

  void _onSyncChanged() {
    if (!_sync.signedIn) {
      _api?.close();
      _api = null;
      _apiServerUrl = null;
      _apiToken = null;
      notifyListeners();
      return;
    }
    if (_api != null &&
        _apiServerUrl == _sync.serverUrl &&
        _apiToken == _sync.authToken) {
      return;
    }
    _api?.close();
    _apiServerUrl = _sync.serverUrl;
    _apiToken = _sync.authToken;
    _api = RecipeApi(_sync.serverUrl!, token: _sync.authToken);
    _photoCache.clear();
    unawaited(refreshPublic());
  }

  // ---- Local persistence --------------------------------------------------

  Future<File> _getStoreFile() async {
    if (_storeFile != null) return _storeFile!;
    final dir = await getApplicationSupportDirectory();
    _storeFile = File('${dir.path}/luma_recipes.json');
    return _storeFile!;
  }

  Future<Directory> _photoDir() async {
    final dir = await getApplicationSupportDirectory();
    final photos = Directory('${dir.path}/recipe_photos');
    if (!await photos.exists()) await photos.create(recursive: true);
    return photos;
  }

  Future<void> _load() async {
    if (_loadedLocal) return;
    _loadedLocal = true;
    try {
      final file = await _getStoreFile();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map<String, dynamic>) {
          final local = (raw['local'] as List? ?? const [])
              .map((e) => LocalRecipe.fromJson(e as Map<String, dynamic>));
          _local
            ..clear()
            ..addAll(local);
          _favoritePublicIds
            ..clear()
            ..addAll((raw['favoritePublicIds'] as List? ?? const [])
                .cast<String>());
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final file = await _getStoreFile();
      await file.writeAsString(jsonEncode({
        'version': 1,
        'local': _local.map((r) => r.toJson()).toList(),
        'favoritePublicIds': _favoritePublicIds.toList(),
      }));
    } catch (_) {}
  }

  // ---- Private recipe mutations -------------------------------------------

  /// Creates a new local recipe. If [makePublic] and the user is signed in,
  /// it is also published to the shared catalogue. Returns an error message on
  /// a (publish) failure, or null on success — the local recipe is always
  /// saved regardless.
  Future<String?> addLocal({
    required String title,
    String? description,
    required String category,
    required int servings,
    required int prepMinutes,
    required int cookMinutes,
    required List<RecipeIngredient> ingredients,
    required List<String> steps,
    Uint8List? photoBytes,
    bool makePublic = false,
  }) async {
    StorageGuard.instance.ensureWithinLimit();
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    Uint8List? processed;
    String? photoPath;
    if (photoBytes != null) {
      processed = await compute(_processImage, photoBytes);
      photoPath = await _writePhotoFile(id, processed);
    }

    final now = DateTime.now();
    var recipe = LocalRecipe(
      id: id,
      title: title,
      description: description,
      category: category,
      servings: servings,
      prepMinutes: prepMinutes,
      cookMinutes: cookMinutes,
      ingredients: ingredients,
      steps: steps,
      photoPath: photoPath,
      createdAt: now,
      updatedAt: now,
    );
    _local.insert(0, recipe);
    notifyListeners();
    await _persist();
    StorageGuard.instance.scheduleRefresh();

    if (makePublic) {
      return _publish(recipe, processed);
    }
    return null;
  }

  /// Edits an existing local recipe. [photoBytes] null keeps the current
  /// photo; [removePhoto] clears it. If the recipe is already published, the
  /// change is pushed to the server too.
  Future<String?> updateLocal(
    String id, {
    required String title,
    String? description,
    required String category,
    required int servings,
    required int prepMinutes,
    required int cookMinutes,
    required List<RecipeIngredient> ingredients,
    required List<String> steps,
    Uint8List? photoBytes,
    bool removePhoto = false,
    bool makePublic = false,
  }) async {
    final idx = _local.indexWhere((r) => r.id == id);
    if (idx == -1) return 'Recipe not found.';
    var recipe = _local[idx];

    Uint8List? processed;
    String? newPhotoPath = recipe.photoPath;
    if (removePhoto) {
      await _deletePhotoFile(recipe.photoPath);
      newPhotoPath = null;
    } else if (photoBytes != null) {
      processed = await compute(_processImage, photoBytes);
      newPhotoPath = await _writePhotoFile(id, processed);
    }

    recipe = recipe.copyWith(
      title: title,
      description: description,
      category: category,
      servings: servings,
      prepMinutes: prepMinutes,
      cookMinutes: cookMinutes,
      ingredients: ingredients,
      steps: steps,
      photoPath: newPhotoPath,
      updatedAt: DateTime.now(),
    );
    _local[idx] = recipe;
    notifyListeners();
    await _persist();

    if (recipe.isPublished) {
      return _pushUpdate(recipe, processed, removePhoto: removePhoto);
    }
    if (makePublic) {
      // Publishing an edit needs the current photo bytes if we didn't just
      // re-process one from the picker.
      processed ??= await _readPhotoFile(recipe.photoPath);
      return _publish(recipe, processed);
    }
    return null;
  }

  Future<void> deleteLocal(String id) async {
    final idx = _local.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final recipe = _local[idx];
    _local.removeAt(idx);
    notifyListeners();
    await _deletePhotoFile(recipe.photoPath);
    await _persist();
    StorageGuard.instance.scheduleRefresh();
    if (recipe.publicId != null) {
      try {
        await _api?.deleteRecipe(recipe.publicId!);
        await refreshPublic();
      } catch (_) {}
    }
  }

  Future<void> toggleFavoriteLocal(String id) async {
    final idx = _local.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    _local[idx] = _local[idx].copyWith(isFavorite: !_local[idx].isFavorite);
    notifyListeners();
    await _persist();
  }

  /// Removes a published recipe from the public catalogue but keeps the local
  /// copy (it stays in Private, just no longer shared).
  Future<String?> unpublish(String id) async {
    final idx = _local.indexWhere((r) => r.id == id);
    if (idx == -1) return 'Recipe not found.';
    final recipe = _local[idx];
    if (recipe.publicId == null) return null;
    final api = _api;
    if (api == null) return 'Sign in to manage published recipes.';
    try {
      await api.deleteRecipe(recipe.publicId!);
    } on RecipeApiException catch (e) {
      if (!e.isNotFound) return e.message;
    } catch (e) {
      return '$e';
    }
    _local[idx] = recipe.copyWith(publicId: null);
    notifyListeners();
    await _persist();
    await refreshPublic();
    return null;
  }

  Future<String?> _publish(LocalRecipe recipe, Uint8List? photoBytes) async {
    final api = _api;
    if (api == null) {
      return 'Saved privately. Sign in under Settings → Sync to publish it.';
    }
    try {
      final published = await api.publish(
        title: recipe.title,
        description: recipe.description,
        category: recipe.category,
        servings: recipe.servings,
        prepMinutes: recipe.prepMinutes,
        cookMinutes: recipe.cookMinutes,
        ingredients: recipe.ingredients,
        steps: recipe.steps,
      );
      if (photoBytes != null) {
        try {
          await api.uploadRecipePhoto(published.id, photoBytes);
        } catch (_) {}
      }
      final idx = _local.indexWhere((r) => r.id == recipe.id);
      if (idx != -1) {
        _local[idx] = _local[idx].copyWith(publicId: published.id);
        notifyListeners();
        await _persist();
      }
      await refreshPublic();
      return null;
    } on RecipeApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not publish: $e';
    }
  }

  Future<String?> _pushUpdate(LocalRecipe recipe, Uint8List? photoBytes,
      {bool removePhoto = false}) async {
    final api = _api;
    if (api == null || recipe.publicId == null) return null;
    try {
      await api.updateRecipe(
        recipe.publicId!,
        title: recipe.title,
        description: recipe.description,
        category: recipe.category,
        servings: recipe.servings,
        prepMinutes: recipe.prepMinutes,
        cookMinutes: recipe.cookMinutes,
        ingredients: recipe.ingredients,
        steps: recipe.steps,
      );
      if (photoBytes != null) {
        try {
          final photoId = await api.uploadRecipePhoto(recipe.publicId!, photoBytes);
          _photoCache.remove(photoId);
        } catch (_) {}
      }
      await refreshPublic();
      return null;
    } on RecipeApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not update the published copy: $e';
    }
  }

  // ---- Public catalogue ---------------------------------------------------

  Future<void> refreshPublic() async {
    final api = _api;
    if (api == null) {
      _public = [];
      _publicError = null;
      notifyListeners();
      return;
    }
    _loadingPublic = true;
    _publicError = null;
    notifyListeners();
    try {
      _public = await api.listRecipes();
      _publicError = null;
    } on RecipeApiException catch (e) {
      _publicError = e.message;
    } catch (e) {
      _publicError = 'Could not reach the server.';
    } finally {
      _loadingPublic = false;
      notifyListeners();
    }
  }

  Future<PublicRecipe?> loadRecipeDetail(String id) async {
    final api = _api;
    if (api == null) return null;
    try {
      final full = await api.getRecipe(id);
      _replacePublic(full);
      return full;
    } catch (_) {
      // Fall back to whatever we already have cached.
      for (final r in _public) {
        if (r.id == id) return r;
      }
      return null;
    }
  }

  void _replacePublic(PublicRecipe recipe) {
    final idx = _public.indexWhere((r) => r.id == recipe.id);
    if (idx != -1) {
      _public[idx] = recipe;
    } else {
      _public = [recipe, ..._public];
    }
    notifyListeners();
  }

  Future<void> toggleFavoritePublic(String id) async {
    if (_favoritePublicIds.contains(id)) {
      _favoritePublicIds.remove(id);
    } else {
      _favoritePublicIds.add(id);
    }
    notifyListeners();
    await _persist();
  }

  /// Adds or updates the current user's review of a public recipe, optionally
  /// with a photo. Returns an error message or null on success.
  Future<String?> submitReview(
    String recipeId, {
    required int rating,
    required String text,
    Uint8List? photoBytes,
  }) async {
    final api = _api;
    if (api == null) return 'Sign in to review recipes.';
    try {
      var full = await api.putReview(recipeId, rating: rating, text: text);
      if (photoBytes != null) {
        final processed = await compute(_processImage, photoBytes);
        try {
          final photoId = await api.uploadReviewPhoto(recipeId, processed);
          _photoCache.remove(photoId);
        } catch (_) {}
        full = await api.getRecipe(recipeId);
      }
      _replacePublic(full);
      return null;
    } on RecipeApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not post your review: $e';
    }
  }

  Future<String?> deleteMyReview(String recipeId) async {
    final api = _api;
    if (api == null) return 'Sign in to manage reviews.';
    try {
      final full = await api.deleteReview(recipeId);
      _replacePublic(full);
      return null;
    } on RecipeApiException catch (e) {
      return e.message;
    } catch (e) {
      return '$e';
    }
  }

  // ---- Photos -------------------------------------------------------------

  /// Returns the bytes of a public photo by id, fetching and caching on first
  /// use. A cached null means "known to be missing", so we don't refetch.
  Future<Uint8List?> publicPhoto(String photoId) async {
    if (_photoCache.containsKey(photoId)) return _photoCache[photoId];
    final api = _api;
    if (api == null) return null;
    if (_photoInFlight.contains(photoId)) return null;
    _photoInFlight.add(photoId);
    try {
      final bytes = await api.fetchMedia(photoId);
      _photoCache[photoId] = bytes;
      return bytes;
    } catch (_) {
      return null;
    } finally {
      _photoInFlight.remove(photoId);
    }
  }

  Future<String?> _writePhotoFile(String id, Uint8List bytes) async {
    try {
      final dir = await _photoDir();
      final file = File('${dir.path}/$id.jpg');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _readPhotoFile(String? path) async {
    if (path == null) return null;
    try {
      final file = File(path);
      if (await file.exists()) return file.readAsBytes();
    } catch (_) {}
    return null;
  }

  Future<void> _deletePhotoFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
