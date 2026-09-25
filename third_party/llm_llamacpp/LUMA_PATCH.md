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
- `pubspec.yaml`: `resolution: workspace` and `dev_dependencies` removed so it
  resolves as a path dependency.

The version stays `0.7.0` on purpose: the hook downloads prebuilts for the
version in this pubspec, and the ABI fingerprint is computed from the
unchanged bindings, so Android, Windows, Linux and macOS fetch exactly the
same binaries as before.

Drop this override once an upstream release ships a working iOS bundle.
