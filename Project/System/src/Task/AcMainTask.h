//
//  AcMainTask.h
//  pop'n rhythmin
//
//  The ARCADE-mode task: arcade song select + option select + note play, driving
//  the arcade note engine (AcNoteMng, already reconstructed). Launched by the mode
//  menu (MenuMainTask). Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (ctor AcMainTask_ctor FUN_00099ab0, update AcMainTask_update FUN_00099d18).
//
//  AcMainTask_update is the app's largest function (~24 KB / ~4300 decompiled lines,
//  heavily inlined). It is reconstructed in pieces from the on-disk decompile
//  (.decompile/AcMainTask_update.c): update() is the touch/SE preamble + a dispatch
//  over the play-data state (@ +0x9f8) into one handler method per state; each state's
//  inlined body is lifted into its own method. Progress tracked in STUBS.md.
//

#pragma once

#include <cstdint>

#include "C_TASK.h"
#include "Random.h"      // embedded PRNG at this+0x4f4 (Ghidra: FUN_00062b20)

struct neTouchPoint;   // System/src/Render/neGraphics.h (touch pool record)

class AcMainTask : public C_TASK {
public:
    AcMainTask();                        // Ghidra: AcMainTask_ctor (FUN_00099ab0)
    void update(int deltaMs) override;   // Ghidra: AcMainTask_update (FUN_00099d18)

private:
    // The arcade task is a ~0xa00-byte object. Its select/option/play state lives in
    // a flat play-data block the ctor memsets over +0x28..+0x9fc and then reaches by
    // byte offset from `this` (there are hundreds of fields). Reserve it so the raw-
    // offset access is in-bounds. C_TASK's base is exactly 0x28 bytes.
    uint8_t m_playData[0xa00 - 0x28] = {};

    // Per-frame touch classification produced by update()'s preamble. In the binary
    // these are shared stack locals of the one megafunction (bVar46 / local_308 /
    // puVar25); as the function is de-inlined into per-state methods they are hoisted
    // to members. Recomputed every frame before the state dispatch and read by the
    // select-list states as those are reconstructed.
    bool m_frameDragging = false;                  // a finger is currently held down
    bool m_frameTapped = false;                    // a tap landed this frame
    const neTouchPoint *m_frameTapTouch = nullptr; // the tapped touch (when m_frameTapped)

    // Reach an arbitrary play-data field by its Ghidra byte offset from `this`.
    template <typename T> T &field(int off) {
        return *reinterpret_cast<T *>(reinterpret_cast<char *>(this) + off);
    }

    // The main play-data state field the update switch dispatches on (@ +0x9f8).
    int &state() { return field<int>(0x9f8); }

    // The arcade RNG the ctor constructs in place at this+0x4f4 (map / character /
    // treasure picks). Reached through the raw play-data storage.
    Random &rng() { return *reinterpret_cast<Random *>(&field<uint8_t>(0x4f4)); }

    // Per-state handlers, lifted from AcMainTask_update's inlined switch cases.
    // Reconstructed incrementally from .decompile/AcMainTask_update.c; each sets the
    // next state before returning.
    void stateInit();          // case 0  (setup, then BGM or the no-treasure path)
    void stateFadeIn();        // case 1  (fade the select scene, open the sugoroku map)
    void stateTreasureCheck(); // case 2  (read the temp-treasure record, branch)

    // Inlined sub-routines lifted out of the 24 KB body (their own reconstruction
    // pieces). Declared here and called as real functions.
    void setupScene();         // Ghidra: FUN_0009fc90 (build the select/map scene)
    void loadTreasureMap();    // Ghidra: FUN_000a0b58 (load the sugoroku map data)
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
