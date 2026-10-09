# Vendored llm_llamacpp 0.7.0

A copy of [llm_llamacpp 0.7.0](https://pub.dev/packages/llm_llamacpp)
(MIT, see `LICENSE`), used through `dependency_overrides` in luma's
`pubspec.yaml`. Only `lib/`, `hook/` and `src/` are kept.

## What differs from upstream

- `hook/build.dart` returns without contributing assets when building for
  iOS. Every upstream iOS prebuilt (0.4.0–0.7.0) contains only static `.a`
  libraries, not the `llama.framework` the hook looks for, so the hook falls
  back to a from-source build that a pub.dev copy cannot perform (no llama.cpp
  checkout). The iOS app build then fails, and Flutter reports it as a
  "Development Team" error. luma hides the offline model on iOS.
- Prompts are evaluated in `n_batch`-sized chunks (`src/prompt_decoder.dart`)
  instead of one `llama_decode` call. Upstream hands the whole prompt over at
  once, and llama.cpp's `GGML_ASSERT(n_tokens_all <= cparams.n_batch)` then
  aborts the process for any prompt over 512 tokens — which the Assistant's
  tool schemas alone exceed. A prompt that cannot fit `n_ctx` now returns an
  `InferenceError` instead of being decoded.
- The helper isolate keeps one model + context loaded between requests
  instead of loading, building and freeing them every time
  (`src/cached_inference_session.dart`), and snapshots the evaluated
  conversation up to the start of the final user turn with
  `llama_state_seq_get_data`. The next turn restores that snapshot and only
  evaluates what is new. It is a saved state, not a KV-cache trim, because
  Qwen3.5's recurrent layers can't roll back to an earlier position. Measured
  on the Assistant's ~1k-token system prompt + tools (RX 9060 XT): "hi" went
  from ~6.3 s to ~0.4 s. Requests with a LoRA adapter skip the cache.
  `PersistentInferenceIsolate.releaseCachedSession()` (exported) frees it —
  Windows can't delete a model file that is still memory-mapped.
- ChatML prompts for a model whose template knows `<think>` get an empty
  `<think>\n\n</think>\n\n` after the assistant header — what Qwen's Jinja
  template emits for `enable_thinking=false`, which
  `llama_chat_apply_template` can't express.
- `streamChat` maps `LLMChatOptions` (`maxOutputTokens`, `temperature`,
  `topP`, `topK`) onto `GenerationOptions`. Upstream passed
  `const GenerationOptions()`, silently ignoring them (2048-token cap).
  `backendOptions['repeatPenalty']` maps onto `repeatPenalty`, since
  `LLMChatOptions` has no field for it. Frequency and presence penalties are
  left unmapped: upstream's conversion turns a positive OpenAI-style value
  into a negative llama.cpp one, which rewards repetition.
- A request with `nGpuLayers == 0` loads the model with an empty
  `llama_model_params.devices` list (`src/inference_isolate_handler.dart`).
  Otherwise llama.cpp still offloads large prompt batches to any registered
  GPU backend, and the Android arm64 bundle ships `libggml-vulkan.so`, which
  the loader registers — so a phone that asked for the CPU ran Vulkan anyway,
  and a mobile driver fault killed the app on its first prompt.
- A request with `nGpuLayers > 0` on a build that can offload loads the
  model with `LLAMA_LOAD_MODE_NONE` instead of memory-mapping it
  (`src/inference_isolate_handler.dart`). llama.cpp can't unmap the
  offloaded parts of a mapping on Windows, so the whole 2.7 GB desktop
  model stayed in the app's working set next to its copy in VRAM.
- A `qwenXml` tool-call format (`src/tool_calls/`) for Qwen3.5, whose
  template wants `<tool_call><function=fn><parameter=a>…` rather than
  Hermes JSON. Upstream matched it as Hermes on the `<tool_call>` tag, so
  it prompted for JSON and parsed only JSON, and every call the model wrote
  was dropped. The tool list is written verbatim from the template, ahead of
  the system prompt, and tool results go back as `<tool_response>` user
  turns; the conversation snapshot skips those to land on the real user turn.
- `pubspec.yaml`: `resolution: workspace` and `dev_dependencies` removed so it
  resolves as a path dependency.

The version stays `0.7.0` on purpose: the hook downloads prebuilts for the
version in this pubspec, and the ABI fingerprint is computed from the
unchanged bindings, so Android, Windows, Linux and macOS fetch exactly the
same binaries as before.

Drop this override once an upstream release ships a working iOS bundle.
