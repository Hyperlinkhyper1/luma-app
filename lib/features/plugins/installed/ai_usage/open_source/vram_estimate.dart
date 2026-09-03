/// Sizing an open-weight model against the hardware someone actually owns.
///
/// The numbers here are an estimate and the UI says so. Weight memory is exact
/// arithmetic; the KV cache is a calibrated approximation, because the
/// catalogue knows a model's parameter count but not its layer count or
/// attention shape.
library;

import 'dart:math' as math;

/// One quantisation someone might download, and what it costs per weight.
///
/// The bit figures are the effective average over a whole GGUF including its
/// unquantised tensors, not the nominal name — `Q4_K_M` stores most weights at
/// 4 bits but averages nearer 4.8, and sizing against 4.0 would tell people a
/// model fits when it doesn't.
enum Quantization {
  fp16('FP16', 16.0, 'Full precision. What the weights ship as.'),
  q8('Q8_0', 8.5, 'Near-lossless. The safe choice when it fits.'),
  q6('Q6_K', 6.6, 'Very close to Q8, noticeably smaller.'),
  q5('Q5_K_M', 5.7, 'Small quality loss, good balance.'),
  q4('Q4_K_M', 4.8, 'The usual pick. Real but modest quality loss.'),
  q3('Q3_K_M', 3.9, 'Visible quality loss. For fitting one tier up.'),
  iq2('IQ2_M', 2.7, 'Heavy loss. Last resort to fit at all.');

  const Quantization(this.label, this.bitsPerWeight, this.blurb);

  final String label;
  final double bitsPerWeight;
  final String blurb;
}

/// How much memory the KV cache takes per billion parameters per 1K tokens,
/// in gigabytes, at 16-bit.
///
/// Calibrated against the modern grouped-query layouts (8 KV heads, 128 head
/// dim) that open-weight models overwhelmingly use: an 8B model of that shape
/// needs ~0.125 GB per 1K tokens and a 70B needs ~0.33, which this curve
/// reproduces to within a few percent. A model with an unusual attention shape
/// will be off, which is why the result is presented as an estimate.
const double _kvCoefficient = 0.045;
const double _kvExponent = 0.47;

/// Fixed overhead for the runtime itself — CUDA/Metal context, activations,
/// the compute buffer. Roughly flat across model sizes in practice.
const double kRuntimeOverheadGb = 1.0;

/// A memory estimate for running one model at one quantisation and context.
class VramEstimate {
  const VramEstimate({
    required this.weightsGb,
    required this.kvCacheGb,
    required this.overheadGb,
  });

  final double weightsGb;
  final double kvCacheGb;
  final double overheadGb;

  double get totalGb => weightsGb + kvCacheGb + overheadGb;
}

/// Memory needed for [parametersB] billion parameters at [quantization], with
/// [contextTokens] of context.
///
/// [kvCacheBits] is the cache's own precision — llama.cpp and vLLM can both
/// hold it at 8 bits, which roughly halves the context cost and is often what
/// makes a long context fit.
VramEstimate estimateVram({
  required double parametersB,
  required Quantization quantization,
  required int contextTokens,
  double kvCacheBits = 16,
}) {
  // A billion parameters at 8 bits per weight is 1 GB, so bits/8 gives GB per
  // billion directly.
  final weightsGb = parametersB * quantization.bitsPerWeight / 8;

  final contextK = contextTokens / 1000;
  final kvGb = _kvCoefficient *
      _pow(parametersB, _kvExponent) *
      contextK *
      (kvCacheBits / 16);

  return VramEstimate(
    weightsGb: weightsGb,
    kvCacheGb: kvGb,
    overheadGb: kRuntimeOverheadGb,
  );
}

/// How comfortably a model fits in a given amount of memory.
enum FitVerdict {
  /// Fits with room to spare for the OS and a display.
  comfortable,

  /// Fits, but with little headroom — expect to close other things.
  tight,

  /// Does not fit in memory alone; layers spill to system RAM and generation
  /// slows by an order of magnitude.
  spills,

  /// Well past what the device has.
  wontRun,
}

/// Judges [estimate] against [availableGb].
///
/// The thresholds leave a margin rather than comparing straight against the
/// total: a GPU that is also driving a display never has its full nominal
/// memory free, and "fits in exactly 24.0 GB" is how people end up with a
/// model that loads and then crashes on the first long prompt.
FitVerdict fitIn(VramEstimate estimate, double availableGb) {
  final needed = estimate.totalGb;
  if (needed <= availableGb * 0.85) return FitVerdict.comfortable;
  if (needed <= availableGb * 0.97) return FitVerdict.tight;
  if (needed <= availableGb * 1.6) return FitVerdict.spills;
  return FitVerdict.wontRun;
}

/// A device someone might run a model on.
///
/// Unified-memory machines are listed with the memory a GPU task can actually
/// claim, not the machine's total — macOS caps that below the installed RAM.
class HardwareProfile {
  const HardwareProfile(this.name, this.vramGb, {this.unified = false});

  final String name;
  final double vramGb;

  /// True for shared CPU/GPU memory (Apple silicon, integrated graphics),
  /// where the figure is a usable share rather than dedicated memory.
  final bool unified;
}

/// A starting list of common devices. The calculator also takes a typed-in
/// amount, so an unlisted card is never a dead end.
const List<HardwareProfile> kHardwareProfiles = [
  HardwareProfile('RTX 3060 12GB', 12),
  HardwareProfile('RTX 4060 Ti 16GB', 16),
  HardwareProfile('RTX 4070 12GB', 12),
  HardwareProfile('RTX 4080 16GB', 16),
  HardwareProfile('RTX 3090 24GB', 24),
  HardwareProfile('RTX 4090 24GB', 24),
  HardwareProfile('RTX 5090 32GB', 32),
  HardwareProfile('2× RTX 3090', 48),
  HardwareProfile('2× RTX 4090', 48),
  HardwareProfile('A100 40GB', 40),
  HardwareProfile('A100 80GB', 80),
  HardwareProfile('H100 80GB', 80),
  HardwareProfile('Mac 16GB', 10.6, unified: true),
  HardwareProfile('Mac 24GB', 16, unified: true),
  HardwareProfile('Mac 32GB', 21.3, unified: true),
  HardwareProfile('Mac 64GB', 48, unified: true),
  HardwareProfile('Mac 128GB', 96, unified: true),
];

/// Context sizes the calculator offers, in tokens.
const List<int> kContextPresets = [4096, 8192, 16384, 32768, 65536, 131072];

double _pow(double base, double exponent) =>
    base <= 0 ? 0 : math.pow(base, exponent).toDouble();
