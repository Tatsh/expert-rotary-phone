//
//  SeInstance.h
//  pop'n rhythmin
//
//  The play scene pre-creates a handful of one-shot "SE-instance" objects —
//  small playback controllers that wrap a loaded sound and drive it through the
//  per-frame SE mixer. Each object carries a play cursor (+0x40, float frames),
//  a playback rate (+0x44, float; negative = play backwards), a frame count
//  (+0x3c, int) and a command byte (+0x58, int: 0 idle, 1 play-forward, 3
//  play). The combo-milestone jingles (PlayJudge) and the song-clear rank
//  jingles (PlayScore) fire these.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. These three
//  controllers are tiny and fully recovered, so they are provided inline here
//  rather than left as unresolved seams:
//    - SeInstanceIsBusy    Ghidra: FUN_0002cba4  (command byte non-idle query)
//    - SeInstancePlay      Ghidra: FUN_0002cac0  (arm forward/reverse playback)
//    - SeInstancePlayMode  Ghidra: FUN_0002cb24  (issue "play" command,
//    optional rewind)
//    - SeInstanceIsPlaying Ghidra: FUN_0002cb64  (cursor still within its
//    range)
//    - SeInstanceStop      Ghidra: FUN_0002cb5c  (clear the command)
//

#pragma once

// One playback controller. Only the four fields the controllers touch are
// named; the object is owned by the play scene and reached as an opaque
// pointer.
struct SeInstance {
    unsigned char reserved00[0x3c];
    int frameCount; // +0x3c  total frames of the wrapped sound
    float cursor;   // +0x40  current playback position, in frames
    float rate;     // +0x44  playback rate (< 0 plays the sound in reverse)
    unsigned char reserved48[0x10];
    int command; // +0x58  0 idle, 1 play-forward, 3 play, 4 finished (per frame)
};

// True while a command is still pending (command byte != 0). Callers only fire
// a new jingle when the controller is idle. Ghidra: FUN_0002cba4.
inline bool SeInstanceIsBusy(void *instance) {
    return reinterpret_cast<SeInstance *>(instance)->command != 0;
}

// Arm forward (or, for a reverse-rate controller, backward) playback and rewind
// the cursor to the head (or tail). A zero rate is normalised to 1.0. Ghidra:
// FUN_0002cac0.
inline void SeInstancePlay(void *instance) {
    SeInstance *o = reinterpret_cast<SeInstance *>(instance);
    o->command = 1;
    if (o->rate == 0.0f) {
        o->rate = 1.0f;
    } else if (o->rate < 0.0f) {
        o->cursor = static_cast<float>(o->frameCount - 1);
        return;
    }
    o->cursor = 0.0f;
}

// Issue the generic "play" command. With mode == 1 the cursor is also rewound:
// to the head for a forward rate, or to the last frame when the rate runs
// backwards. Ghidra: FUN_0002cb24.
inline void SeInstancePlayMode(void *instance, int mode) {
    SeInstance *o = reinterpret_cast<SeInstance *>(instance);
    o->command = 3;
    if (mode != 1) {
        return;
    }
    if (o->rate <= 0.0f) {
        o->cursor = static_cast<float>(o->frameCount - 1);
    } else {
        o->cursor = 0.0f;
    }
}

// Whether the controller is still running its cursor. An idle (0) or finished
// (4) command counts as stopped; otherwise a reverse-rate sound plays while the
// cursor is still above the head, a forward one while it has not yet reached
// the last frame. Ghidra: FUN_0002cb64.
inline bool SeInstanceIsPlaying(void *instance) {
    SeInstance *o = reinterpret_cast<SeInstance *>(instance);
    if ((o->command | 4) == 4) { // command 0 (idle) or 4 (finished)
        return false;
    }
    if (o->rate <= 0.0f) {
        return (int)o->cursor > 0;
    }
    return (int)o->cursor < o->frameCount;
}

// Stop the controller: clear its command so the per-frame tick skips it.
// Ghidra: FUN_0002cb5c.
inline void SeInstanceStop(void *instance) {
    reinterpret_cast<SeInstance *>(instance)->command = 0;
}

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
