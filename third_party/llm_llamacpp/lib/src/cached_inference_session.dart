part of 'persistent_inference_isolate.dart';

// luma patch — see LUMA_PATCH.md.
//
// Upstream loads the model, builds a context, evaluates the whole prompt and
// frees everything again on every request. For a chat assistant that means
// every turn pays the model load (~0.5–1.5 s), the context/pipeline setup
// (~0.1–0.6 s) and a re-evaluation of the same multi-thousand-token system
// prompt and tool schemas. This keeps one model + context alive in the
// helper isolate and snapshots the evaluated conversation prefix, so a turn
// only evaluates what is new since the last one.
//
// The prefix is restored from a saved sequence state rather than trimmed out
// of the KV cache in place: hybrid/recurrent models (Qwen3.5's gated delta
// net layers) cannot roll their state back to an earlier position, but they
// can load a state saved at that position.

/// The model and context kept alive between requests, plus the saved state
/// of the last evaluated conversation prefix.
class _CachedSession {
  _CachedSession(this.key, this.model, this.ctx);

  final String key;
  final ffi.Pointer<llama_model> model;
  final ffi.Pointer<llama_context> ctx;

  List<int>? _snapshotTokens;
  ffi.Pointer<ffi.Uint8>? _snapshotData;
  int _snapshotSize = 0;

  void dispose(LlamaBindings bindings) {
    _dropSnapshot();
    bindings.llama_free(ctx);
    bindings.llama_model_free(model);
  }

  void _dropSnapshot() {
    final data = _snapshotData;
    if (data != null) calloc.free(data);
    _snapshotData = null;
    _snapshotSize = 0;
    _snapshotTokens = null;
  }

  /// Saves the context's current sequence state as the state after
  /// `tokens[0..length)`.
  void _saveSnapshot(
    LlamaBindings bindings,
    ffi.Pointer<ffi.Int32> tokens,
    int length,
  ) {
    final size = bindings.llama_state_seq_get_size(ctx, 0);
    if (size <= 0) {
      _dropSnapshot();
      return;
    }
    if (_snapshotData == null || _snapshotSize != size) {
      _dropSnapshot();
      _snapshotData = calloc<ffi.Uint8>(size);
    }
    final written = bindings.llama_state_seq_get_data(
      ctx,
      _snapshotData!,
      size,
      0,
    );
    if (written <= 0) {
      _dropSnapshot();
      return;
    }
    _snapshotSize = written;
    _snapshotTokens = [for (var i = 0; i < length; i++) tokens[i]];
  }

  /// Evaluates `tokens[0..nTokens)` into a cleared context, restoring the
  /// saved prefix when it matches and saving a new one at [boundary] — the
  /// start of the final user turn, so the next turn can resume from there.
  ///
  /// Returns the number of prompt tokens that had to be evaluated (for
  /// logging) on success, or an error message.
  (int, String?) decodePrompt(
    LlamaBindings bindings,
    ffi.Pointer<ffi.Int32> tokens,
    int nTokens,
    int boundary,
  ) {
    final memory = bindings.llama_get_memory(ctx);
    bindings.llama_memory_clear(memory, true);

    var start = 0;
    final snapshot = _snapshotTokens;
    if (snapshot != null &&
        snapshot.length < nTokens &&
        snapshot.length <= boundary &&
        _hasPrefix(tokens, snapshot)) {
      final read = bindings.llama_state_seq_set_data(
        ctx,
        _snapshotData!,
        _snapshotSize,
        0,
      );
      if (read > 0) {
        start = snapshot.length;
      } else {
        bindings.llama_memory_clear(memory, true);
      }
    }

    if (boundary > start) {
      final error = decodePromptInBatches(
        bindings,
        ctx,
        tokens,
        boundary,
        start: start,
      );
      if (error != null) return (0, error);
      _saveSnapshot(bindings, tokens, boundary);
    }

    final from = boundary > start ? boundary : start;
    final error = decodePromptInBatches(
      bindings,
      ctx,
      tokens,
      nTokens,
      start: from,
    );
    return (nTokens - start, error);
  }

  static bool _hasPrefix(ffi.Pointer<ffi.Int32> tokens, List<int> prefix) {
    for (var i = 0; i < prefix.length; i++) {
      if (tokens[i] != prefix[i]) return false;
    }
    return true;
  }
}

_CachedSession? _cachedSession;

String _sessionKey(_InferenceRequestMessage request) =>
    '${request.modelPath}|${request.nGpuLayers}|${request.contextSize}|'
    '${request.batchSize}|${request.threads}';

void _releaseCachedSession(LlamaBindings bindings) {
  _cachedSession?.dispose(bindings);
  _cachedSession = null;
}

/// The token count of the rendered conversation up to (not including) its
/// final user turn — where the next turn's prompt will diverge — or 0 when
/// that point can't be located or doesn't tokenize as a clean prefix of
/// [tokens]. Only ChatML-style templates (`<|im_start|>user`) are handled;
/// anything else simply evaluates the whole prompt as before.
int _conversationPrefixLength(
  LlamaBindings bindings,
  ffi.Pointer<llama_vocab> vocab,
  String prompt,
  bool addSpecial,
  ffi.Pointer<ffi.Int32> tokens,
  int nTokens,
) {
  final marker = prompt.lastIndexOf('<|im_start|>user');
  if (marker <= 0) return 0;
  final prefixPtr = prompt.substring(0, marker).toNativeUtf8();
  final prefixBytes = prefixPtr.length;
  final capacity = prefixBytes + 256;
  final prefixTokens = calloc<ffi.Int32>(capacity);
  try {
    final count = bindings.llama_tokenize(
      vocab,
      prefixPtr.cast(),
      prefixBytes,
      prefixTokens,
      capacity,
      addSpecial,
      true,
    );
    if (count <= 0 || count >= nTokens) return 0;
    for (var i = 0; i < count; i++) {
      if (prefixTokens[i] != tokens[i]) return 0;
    }
    return count;
  } finally {
    calloc.free(prefixPtr);
    calloc.free(prefixTokens);
  }
}
