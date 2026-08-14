/// One provider's per-model token rates, in USD per million tokens.
class AiPricingRates {
  const AiPricingRates({
    required this.input,
    required this.output,
    required this.cacheWrite,
    required this.cacheRead,
  });

  final double input;
  final double output;
  final double cacheWrite;
  final double cacheRead;
}
