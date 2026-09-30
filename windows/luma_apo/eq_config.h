#pragma once

// The curve file luma writes to %ProgramData%\luma\apo\eq.bin and the APO
// reads. Fixed size and little-endian; its layout mirrors
// SystemEqConfig.encode in lib/features/plugins/installed/audio_tools/
// system_eq.dart, so change both together.
//
// The file is writable by ordinary users but read inside audiodg, so the
// parser treats it as untrusted: exact size, magic and version, and every
// number is clamped into range before it reaches the filters.

#include <cmath>
#include <cstdint>
#include <cstring>

namespace luma_apo {

constexpr uint32_t kConfigMagic = 0x4F50414C;  // "LAPO"
constexpr uint32_t kConfigVersion = 1;
constexpr uint32_t kMaxBands = 16;

// Matches EqBandType's declaration order in eq.dart.
enum class BandType : uint32_t {
  kHighPass = 0,
  kLowShelf = 1,
  kPeak = 2,
  kHighShelf = 3,
  kLowPass = 4,
};

struct Band {
  BandType type;
  bool enabled;
  double frequency;
  double gain_db;
  double q;
};

struct Config {
  bool enabled = false;
  double preamp_db = 0;
  uint32_t band_count = 0;
  Band bands[kMaxBands] = {};
};

constexpr size_t kHeaderBytes = 20;
constexpr size_t kBandBytes = 20;
constexpr size_t kConfigBytes = kHeaderBytes + kMaxBands * kBandBytes;

inline uint32_t ReadU32(const uint8_t* p) {
  return uint32_t(p[0]) | (uint32_t(p[1]) << 8) | (uint32_t(p[2]) << 16) |
         (uint32_t(p[3]) << 24);
}

inline float ReadF32(const uint8_t* p) {
  const uint32_t bits = ReadU32(p);
  float f;
  std::memcpy(&f, &bits, sizeof f);
  return f;
}

inline double Clamp(double v, double lo, double hi) {
  if (!(v == v)) return lo;
  return v < lo ? lo : (v > hi ? hi : v);
}

// Returns false (leaving [out] untouched) for anything that isn't a
// well-formed version-1 file.
inline bool ParseConfig(const uint8_t* data, size_t size, Config* out) {
  if (data == nullptr || size != kConfigBytes) return false;
  if (ReadU32(data) != kConfigMagic) return false;
  if (ReadU32(data + 4) != kConfigVersion) return false;
  const uint32_t count = ReadU32(data + 16);
  if (count > kMaxBands) return false;

  Config c;
  c.enabled = ReadU32(data + 8) != 0;
  c.preamp_db = Clamp(ReadF32(data + 12), -24, 12);
  c.band_count = count;
  for (uint32_t i = 0; i < count; i++) {
    const uint8_t* b = data + kHeaderBytes + i * kBandBytes;
    const uint32_t type = ReadU32(b);
    if (type > uint32_t(BandType::kLowPass)) return false;
    c.bands[i].type = BandType(type);
    c.bands[i].enabled = ReadU32(b + 4) != 0;
    c.bands[i].frequency = Clamp(ReadF32(b + 8), 20, 20000);
    c.bands[i].gain_db = Clamp(ReadF32(b + 12), -24, 24);
    c.bands[i].q = Clamp(ReadF32(b + 16), 0.3, 8);
  }
  *out = c;
  return true;
}

}  // namespace luma_apo
