import '../../../../l10n/current_l.dart';
import 'texture_pack_types.dart';

/// Web stub: there is no filesystem to find a Minecraft installation on, so
/// the preview stays on its flat block colours.

Future<String?> loadSavedTextureSourcePath() async => null;

Future<void> saveTextureSourcePath(String path) async {}

Future<List<TexturePackSource>> findTextureSources() async =>
    const <TexturePackSource>[];

AtlasBitmap readAndBuildAtlas(String path) =>
    throw UnsupportedError(currentL.textureNeedsFilesystem);
