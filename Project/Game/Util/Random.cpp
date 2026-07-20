//
//  Random.cpp
//  pop'n rhythmin
//
//  See Random.h. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (original: Project/Game/Util/Random.cpp, v203).
//

#include "Random.h"

#include <cassert>

namespace {
// Marsaglia's canonical xorshift128 seeds (the exact constants the ctor
// writes).
constexpr uint32_t kSeedX = 123456789; // 0x075bcd15
constexpr uint32_t kSeedY = 362436069; // 0x159a55e5
constexpr uint32_t kSeedZ = 521288629; // 0x1f123bb5
constexpr uint32_t kSeedW = 88675123;  // 0x05491333
} // namespace

// Ghidra: FUN_00062b20.
Random::Random() : m_x(kSeedX), m_y(kSeedY), m_z(kSeedZ), m_w(kSeedW) {
}

// Ghidra: FUN_00062b54 (empty).
Random::~Random() {
}

// Ghidra: FUN_00062b5c — x/y/z back to canonical, w = seed.
void Random::setSeed(uint32_t seed) {
    m_x = kSeedX;
    m_y = kSeedY;
    m_z = kSeedZ;
    m_w = seed;
}

// xorshift128 (Ghidra: the inlined step inside FUN_00062be0). Verified against
// the `gt`-predicated block at 0x62b80: t = x ^ (x << 11) (eor lsl #0xb); word
// down-shift x=y, y=z, z=w; w_new = (t ^ (t >> 8)) ^ w ^ (w >> 19). XOR is
// associative, so this matches the source expression.
uint32_t Random::next() {
    uint32_t t = m_x ^ (m_x << 11);
    m_x = m_y;
    m_y = m_z;
    m_z = m_w;
    m_w = m_w ^ (m_w >> 19) ^ (t ^ (t >> 8));
    return m_w;
}

// Ghidra: FUN_00062be0 (GetRandRangeInt @ Random.cpp:0x77). Entry does
// `subs r1,#1` then branches to the shared body at 0x62b80; the assert string
// pool (0x107183..) confirms "GetRandRangeInt", the Random.cpp path, and the
// condition "max >= 0". The body BICs bit 31 (& 0x7fffffff) then tail-calls the
// unsigned modulo helper with the restored `max`.
int Random::getRandRangeInt(int max) {
    assert(max >= 0);
    return static_cast<int>((next() & 0x7fffffff) % static_cast<uint32_t>(max));
}
