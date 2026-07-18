//
//  neFrameTimer.h
//  pop'n rhythmin
//
//  A wall-clock stopwatch: an 8-byte {sec, usec} snapshot taken at reset(),
//  read back as elapsed MILLISECONDS. Used by MainViewController to pace the
//  task update and render steps. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin (reset FUN_00028084, elapsed FUN_0002808c).
//  Header-only: the two methods are small and inline.
//

#pragma once

#include <sys/time.h>

class neFrameTimer {
public:
    // Ghidra: FUN_00028084 — snapshot the current time.
    void reset() {
        timeval now;
        gettimeofday(&now, nullptr);
        m_sec = now.tv_sec;
        m_usec = now.tv_usec;
    }

    // Ghidra: FUN_0002808c — MILLISECONDS elapsed since the last reset(). The
    // binary computes sec_delta*1000 + usec_delta/1000 (both NEON vcvt.f32.s32,
    // divisor/scale DAT_000280d0 = 1000.0); an earlier reconstruction used
    // /1000000 (seconds), which was 1000x off and broke both consumers (the
    // ne::C_TASK::updateAll millisecond delta and the draw() lag guard, whose
    // threshold DAT_0000be7c = 1000.0f is a millisecond value).
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

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
