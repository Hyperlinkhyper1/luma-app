#pragma once

// A C++ port of EqProcessor in lib/features/plugins/installed/audio_tools/
// eq.dart: RBJ cookbook biquads in transposed direct form II, then the same
// soft limiter, so the system-wide EQ sounds exactly like the in-app one.
//
// Everything here runs on audiodg's real-time thread: no allocation, no
// locks, no system calls.

#include <cmath>
#include <cstdint>

#include "eq_config.h"

namespace luma_apo {

constexpr uint32_t kMaxChannels = 32;

struct Coefficients {
  double b0 = 1, b1 = 0, b2 = 0, a1 = 0, a2 = 0;
};

inline Coefficients CoefficientsFor(const Band& band, double sample_rate) {
  constexpr double kPi = 3.14159265358979323846;
  const double f0 = Clamp(band.frequency, 20, sample_rate * 0.49);
  const double w0 = 2 * kPi * f0 / sample_rate;
  const double cos_w = std::cos(w0);
  const double sin_w = std::sin(w0);
  const double alpha = sin_w / (2 * band.q);
  const double a = std::pow(10.0, band.gain_db / 40);
  const double sqrt_a2_alpha = 2 * std::sqrt(a) * alpha;

  double b0, b1, b2, a0, a1, a2;
  switch (band.type) {
    case BandType::kLowShelf:
      b0 = a * ((a + 1) - (a - 1) * cos_w + sqrt_a2_alpha);
      b1 = 2 * a * ((a - 1) - (a + 1) * cos_w);
      b2 = a * ((a + 1) - (a - 1) * cos_w - sqrt_a2_alpha);
      a0 = (a + 1) + (a - 1) * cos_w + sqrt_a2_alpha;
      a1 = -2 * ((a - 1) + (a + 1) * cos_w);
      a2 = (a + 1) + (a - 1) * cos_w - sqrt_a2_alpha;
      break;
    case BandType::kHighShelf:
      b0 = a * ((a + 1) + (a - 1) * cos_w + sqrt_a2_alpha);
      b1 = -2 * a * ((a - 1) + (a + 1) * cos_w);
      b2 = a * ((a + 1) + (a - 1) * cos_w - sqrt_a2_alpha);
      a0 = (a + 1) - (a - 1) * cos_w + sqrt_a2_alpha;
      a1 = 2 * ((a - 1) - (a + 1) * cos_w);
      a2 = (a + 1) - (a - 1) * cos_w - sqrt_a2_alpha;
      break;
    case BandType::kHighPass:
      b0 = (1 + cos_w) / 2;
      b1 = -(1 + cos_w);
      b2 = (1 + cos_w) / 2;
      a0 = 1 + alpha;
      a1 = -2 * cos_w;
      a2 = 1 - alpha;
      break;
    case BandType::kLowPass:
      b0 = (1 - cos_w) / 2;
      b1 = 1 - cos_w;
      b2 = (1 - cos_w) / 2;
      a0 = 1 + alpha;
      a1 = -2 * cos_w;
      a2 = 1 - alpha;
      break;
    case BandType::kPeak:
    default:
      b0 = 1 + alpha * a;
      b1 = -2 * cos_w;
      b2 = 1 - alpha * a;
      a0 = 1 + alpha / a;
      a1 = -2 * cos_w;
      a2 = 1 - alpha / a;
      break;
  }
  Coefficients c;
  c.b0 = b0 / a0;
  c.b1 = b1 / a0;
  c.b2 = b2 / a0;
  c.a1 = a1 / a0;
  c.a2 = a2 / a0;
  return c;
}

// Linear below 0.8, then eases towards +-1 so peaks never hard-clip.
inline double SoftClip(double x) {
  const double a = std::fabs(x);
  if (a <= 0.8) return x;
  const double shaped = 0.8 + 0.2 * std::tanh((a - 0.8) / 0.2);
  return x < 0 ? -shaped : shaped;
}

class Processor {
 public:
  // Channels beyond kMaxChannels pass through untouched.
  void Configure(double sample_rate, uint32_t channels) {
    sample_rate_ = sample_rate;
    channels_ = channels < kMaxChannels ? channels : kMaxChannels;
    Reset();
  }

  void Reset() {
    for (auto& band : state_) {
      for (auto& ch : band) {
        ch[0] = 0;
        ch[1] = 0;
      }
    }
  }

  // Filter state survives Apply, so the curve can move while audio flows
  // without clicks; it is only cleared when the set of bands changes.
  void Apply(const Config& config) {
    uint32_t active = 0;
    for (uint32_t i = 0; i < config.band_count && i < kMaxBands; i++) {
      if (!config.bands[i].enabled) continue;
      coeffs_[active++] = CoefficientsFor(config.bands[i], sample_rate_);
    }
    if (active != band_count_) {
      band_count_ = active;
      Reset();
    }
    preamp_ = std::pow(10.0, config.preamp_db / 20);
    enabled_ = config.enabled;
  }

  bool enabled() const { return enabled_; }

  // Interleaved float frames, in place.
  void Process(float* samples, uint32_t frames, uint32_t stride) {
    if (!enabled_) return;
    for (uint32_t f = 0; f < frames; f++) {
      float* frame = samples + size_t(f) * stride;
      for (uint32_t ch = 0; ch < channels_; ch++) {
        double x = frame[ch] * preamp_;
        for (uint32_t b = 0; b < band_count_; b++) {
          const Coefficients& c = coeffs_[b];
          double* s = state_[b][ch];
          const double y = c.b0 * x + s[0];
          s[0] = c.b1 * x - c.a1 * y + s[1];
          s[1] = c.b2 * x - c.a2 * y;
          // Silence would otherwise decay into denormals, which are slow
          // enough to glitch the whole audio engine.
          if (std::fabs(s[0]) < 1e-30) s[0] = 0;
          if (std::fabs(s[1]) < 1e-30) s[1] = 0;
          x = y;
        }
        frame[ch] = float(SoftClip(x));
      }
    }
  }

 private:
  double sample_rate_ = 48000;
  uint32_t channels_ = 0;
  uint32_t band_count_ = 0;
  double preamp_ = 1;
  bool enabled_ = false;
  Coefficients coeffs_[kMaxBands];
  double state_[kMaxBands][kMaxChannels][2] = {};
};

}  // namespace luma_apo
