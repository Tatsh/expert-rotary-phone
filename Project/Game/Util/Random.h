//
//  Random.h
//  pop'n rhythmin
//
//  Marsaglia xorshift128 pseudo-random generator. Reconstructed from Ghidra
//  project rb420, program PopnRhythmin; the original translation unit is named
//  in an assert string baked into the binary:
//    /Users/usr10013727/Documents/Project/Rhythmin/branches/v203/Project/Game/Util/Random.cpp
//  and the range method there is GetRandRangeInt (assert at Random.cpp:0x77).
//
//  The state is the classic 4-word xorshift128 vector seeded with Marsaglia's
//  canonical constants. The object carries a vtable (its only virtual is an
//  empty destructor), so its layout is { vptr, x, y, z, w } — matching the
//  arcade task, which embeds one at this+0x4f4.
//
//  Ghidra: ctor FUN_00062b20, dtor FUN_00062b54, setSeed FUN_00062b5c,
//  getRandRangeInt FUN_00062be0.
//

#pragma once

#include <cstdint>

class Random {
public:
    // Seed with the canonical xorshift128 constants. Ghidra: FUN_00062b20.
    Random();

    // The class is polymorphic in the binary (single vtable slot: an empty dtor).
    // Ghidra: FUN_00062b54.
    virtual ~Random();

    // Reset x/y/z to the canonical constants and take `seed` as the w word (the
    // game seeds this with time() before a shuffle). Ghidra: FUN_00062b5c.
    void setSeed(uint32_t seed);

    // A uniformly-distributed integer in [0, max). Asserts max >= 0. Ghidra:
    // FUN_00062be0 (GetRandRangeInt): advances the generator and reduces the low
    // 31 bits modulo max.
    int getRandRangeInt(int max);

private:
    // xorshift128 step: returns the next 32-bit word and advances the state.
    uint32_t next();

    uint32_t m_x; // +0x04
    uint32_t m_y; // +0x08
    uint32_t m_z; // +0x0c
    uint32_t m_w; // +0x10
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
