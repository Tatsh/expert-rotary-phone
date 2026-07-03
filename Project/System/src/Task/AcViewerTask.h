//
//  AcViewerTask.h
//  pop'n rhythmin
//
//  The ARCADE-VIEWER NOTE-PLAY task: the actual pop'n-style rhythm gameplay screen
//  reached from the "arcade viewer" (GotoAcViewer). It loads the chosen ac chart,
//  builds the group-7 "arcade_viewer" HUD, runs the touch/flick input + play-state
//  machine, and each frame drives the arcade note engine (AcNoteMng) plus the note /
//  life-gauge / HUD-digit draw passes. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin.
//
//  NAMING NOTE: Ghidra labels this class's methods acMainTask* (setup FUN_0002230c,
//  update FUN_00021678, dtor thunk task_delete FUN_000215d8) because AppDelegate holds
//  it in its `acMainTask` property (setAcMainTask:). It is NOT the same class as the
//  repo's existing AcMainTask (the arcade sugoroku/treasure SELECT scene, ctor
//  FUN_00099ab0, state @ +0x9f8, embedded RNG @ +0x4f4): this task has a distinct
//  vtable (@ 0x130bb8), its play state lives @ +0x20c, and it drives AcNoteMng rather
//  than the sugoroku map. It is kept in its own file to avoid clobbering that class.
//
//  This task's storage IS the play data the draw/HUD passes reach by flat byte offset
//  from `this` (screen size @ +0x104/+0x108, per-lane note frames @ +0x158, digit
//  textures @ +0x2c, gauge value @ +0x1c8/+0x1ca, state @ +0x20c — see the offset
//  citations in AcViewerTask.mm). The whole object is a ~0x210-byte C_TASK subclass;
//  the hundreds of layout scalars are reached through the raw-offset storage below.
//

#pragma once

#include <cstdint>

#include "C_TASK.h"

// The registered group-7 per-layer HUD draw callback (score / combo / music-title /
// gauge-digit blitter). It is a C function-pointer callback installed by setup() via
// setAepCallbacks(aep, 7, &AcViewerHudDraw, this); the trailing `context` is the owning
// AcViewerTask. Ghidra: aepHudDrawCallback (registered id 0x23359). @ 0x23358
void AcViewerHudDraw(int child, int frame, int x, int y, int scaleX, int scaleY,
                     int anchorX, int anchorY, int color, int alpha, int16_t rotation,
                     int blend, int p13, int p14, void *context);

class AcViewerTask : public C_TASK {
public:
    // Constructed by the engine when the arcade viewer starts play (its ctor/vtable
    // live @ 0x130bb8; not part of this reconstruction batch).
    AcViewerTask();
    ~AcViewerTask() override;            // @ 0x215d8 (task_delete deleting-dtor: base + delete)
    void update(int deltaMs) override;   // @ 0x21678  acMainTaskUpdate

private:
    void setup();          // @ 0x2230c  acMainTaskSetup — resolve the HUD, load chart + SE
    void loadChart();      // @ 0x2316c  loadChartData — pick sheet by difficulty, init AcNoteMng
    void drawActiveNotes();// @ 0x22cac  drawActiveNotes — blit every in-flight note + time line
    void drawLifeGauge();  // @ 0x23000  drawLifeGauge — blit the 24-cell life gauge

    // Frees the task's HUD/textures/layers + AcNoteMng teardown. Called from state 9.
    // Ghidra: AcMainTask::Cleanup.
    void cleanup();        // @ 0x22b44

    // Reach a flat play-data field by its Ghidra byte offset from `this`.
    template <typename T> T &field(int off) {
        return *reinterpret_cast<T *>(reinterpret_cast<char *>(this) + off);
    }

    // The play-state field the update switch dispatches on (@ +0x20c). Confirmed by
    // NEEngine_stopAcMainTask (FUN_0002314c), which flips it 6 -> 0xc on external stop.
    int &state() { return field<int>(0x20c); }

    // The ~0x210-byte flat play-data block (C_TASK base is 0x28). Reserve it so the
    // raw-offset access above is in-bounds.
    uint8_t m_playData[0x214 - 0x28] = {};
};

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
