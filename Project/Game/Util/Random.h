/**
 * @file
 * The Marsaglia xorshift128 pseudo-random generator.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin. The original translation unit is
 * named in an assert string baked into the binary,
 * `/Users/usr10013727/Documents/Project/Rhythmin/branches/v203/Project/Game/Util/Random.cpp`, and
 * the range method there is GetRandRangeInt (assert at Random.cpp:0x77).
 *
 * The state is the classic 4-word xorshift128 vector seeded with Marsaglia's canonical constants.
 * The object carries a vtable (its only virtual is an empty destructor), so its layout is
 * `{ vptr, x, y, z, w }`, matching the arcade task, which embeds one at this+0x4f4.
 *
 * Ghidra: ctor FUN_00062b20, dtor FUN_00062b54, setSeed FUN_00062b5c, getRandRangeInt
 * FUN_00062be0.
 */

#pragma once

#include <cstdint>

/**
 * A Marsaglia xorshift128 pseudo-random generator.
 */
class Random {
public:
    /**
     * Seed the state with the canonical xorshift128 constants.
     * @ghidraAddress 0x62b20
     */
    Random();

    /**
     * Destroy the generator. The class is polymorphic in the binary, whose single vtable
     * slot is this empty destructor.
     * @ghidraAddress 0x62b54
     */
    virtual ~Random();

    /**
     * Reset x, y and z to the canonical constants and take @p seed as the w word.
     *
     * The game seeds this with time() before a shuffle.
     * @param seed The new w word.
     * @ghidraAddress 0x62b5c
     */
    void setSeed(uint32_t seed);

    /**
     * A uniformly-distributed integer below @p max.
     *
     * Advances the generator and reduces the low 31 bits modulo @p max.
     * @param max The exclusive upper bound; asserts it is 0 or above.
     * @return An integer in [0, @p max).
     * @ghidraAddress 0x62be0
     */
    int getRandRangeInt(int max);

private:
    // xorshift128 step: returns the next 32-bit word and advances the state.
    uint32_t next();

    uint32_t m_x; // +0x04
    uint32_t m_y; // +0x08
    uint32_t m_z; // +0x0c
    uint32_t m_w; // +0x10
};
