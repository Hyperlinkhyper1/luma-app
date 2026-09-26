import 'dart:ffi' as ffi;
import 'dart:math' as math;

import 'package:llm_llamacpp/src/bindings/llama_bindings.dart';

/// Evaluates `tokens[start..nTokens)` in chunks of at most the context's
/// `n_batch`.
///
/// llama.cpp guards `llama_decode` with
/// `GGML_ASSERT(n_tokens_all <= cparams.n_batch)`, which aborts the whole
/// process rather than returning an error, so a prompt longer than one batch
/// must never be handed over in a single call. [start] lets a caller that
/// restored an already-evaluated prefix continue from there; positions carry
/// on from the context's memory.
///
/// Returns null on success, or a message describing why the prompt could not
/// be evaluated.
String? decodePromptInBatches(
  LlamaBindings bindings,
  ffi.Pointer<llama_context> ctx,
  ffi.Pointer<ffi.Int32> tokens,
  int nTokens, {
  int start = 0,
}) {
  final nCtx = bindings.llama_n_ctx(ctx);
  if (nTokens >= nCtx) {
    return 'Prompt is $nTokens tokens, which does not fit the '
        '$nCtx-token context window';
  }
  final nBatch = math.max(1, bindings.llama_n_batch(ctx));
  for (var from = start; from < nTokens; from += nBatch) {
    final count = math.min(nBatch, nTokens - from);
    final batch = bindings.llama_batch_get_one(tokens + from, count);
    if (bindings.llama_decode(ctx, batch) != 0) {
      return 'Failed to evaluate prompt';
    }
  }
  return null;
}
