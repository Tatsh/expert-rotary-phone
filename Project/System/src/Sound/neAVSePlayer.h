//
//  neAVSePlayer.h
//  pop'n rhythmin
//
//  Sound-effect backend built on AVFoundation (AVAudioPlayer), used for the SE
//  groups the low-latency CoreAudio backend (neAVCAPlayer) does not serve. It
//  keeps a pool of AVAudioPlayer instances indexed by a play handle. Reconstructed
//  from Ghidra project rb420, program PopnRhythmin (FUN_00021xxx).
//

#pragma once

#include <cstdint>

#import <Foundation/Foundation.h>

// 0x10000000 marks an AVFoundation instance in a play handle (cf. neAVCAPlayer).
constexpr uint32_t kAVSePlayerHandleFlag = 0x10000000;

class neAVSePlayer {
public:
    // Load a URL into a new AVAudioPlayer slot; returns its index, or -1 on
    // failure. Ghidra: FUN_000212d0.
    int load(NSURL *url, bool loop);

    // As load(), but also register a call-name for later lookup. Ghidra: FUN_00021328.
    int loadNamed(NSURL *url, NSString *callName, bool loop);

    // Start the AVAudioPlayer referenced by `handle`. Ghidra: FUN_000214a8.
    bool play(uint32_t handle);

    // AudioSession interruption handling. Ghidra: suspend FUN_00021288 /
    // resume FUN_00021294.
    void suspend();
    void resume();
};

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
