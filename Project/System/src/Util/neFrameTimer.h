//
//  neFrameTimer.h
//  pop'n rhythmin
//
//  A wall-clock stopwatch: an 8-byte {sec, usec} snapshot taken at reset(), read
//  back as elapsed seconds. Used by MainViewController to pace the task update and
//  render steps. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (reset FUN_00028084, elapsedSeconds FUN_0002808c). Header-only: the two methods
//  are small and inline.
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

    // Ghidra: FUN_0002808c — seconds elapsed since the last reset().
    float elapsedSeconds() const {
        timeval now;
        gettimeofday(&now, nullptr);
        return (float)(now.tv_sec - m_sec) + (float)(now.tv_usec - m_usec) / 1000000.0f;
    }

private:
    long m_sec = 0;    // +0x00
    long m_usec = 0;   // +0x04
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
