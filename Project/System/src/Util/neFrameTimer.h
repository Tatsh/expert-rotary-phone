/**
 * @file
 * A wall-clock stopwatch.
 *
 * An 8-byte {sec, usec} snapshot taken at reset(), read back as elapsed
 * milliseconds. Used by MainViewController to pace the task update and render steps.
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (reset FUN_00028084, elapsed
 * FUN_0002808c). Header-only: the two methods are small and inline.
 */

#pragma once

#include <sys/time.h>

/**
 * A wall-clock stopwatch reading back elapsed milliseconds since its last reset.
 */
class neFrameTimer {
public:
    /**
     * Snapshot the current time as the new zero point.
     * @ghidraAddress 0x28084
     */
    void reset() {
        timeval now;
        gettimeofday(&now, nullptr);
        m_sec = now.tv_sec;
        m_usec = now.tv_usec;
    }

    /**
     * Time elapsed since the last reset().
     *
     * The binary computes `sec_delta * 1000 + usec_delta / 1000` (both NEON vcvt.f32.s32,
     * divisor/scale DAT_000280d0 = 1000.0). Both consumers — the ne::C_TASK::updateAll delta and
     * the draw() lag guard, whose threshold DAT_0000be7c = 1000.0f — treat the result as
     * milliseconds.
     * @return Milliseconds elapsed since the last reset().
     * @ghidraAddress 0x2808c
     */
    float elapsedMs() const {
        timeval now;
        gettimeofday(&now, nullptr);
        return static_cast<float>(now.tv_sec - m_sec) * 1000.0f +
               static_cast<float>(now.tv_usec - m_usec) / 1000.0f;
    }

private:
    long m_sec = 0;  // +0x00
    long m_usec = 0; // +0x04
};
