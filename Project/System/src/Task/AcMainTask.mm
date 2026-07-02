//
//  AcMainTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The arcade-mode
//  task (arcade select + sugoroku map + option select + note play through AcNoteMng).
//  AcMainTask_update (FUN_00099d18) is the app's largest function (~24 KB / ~4300
//  decompiled lines, heavily inlined); it is reconstructed in pieces from the on-disk
//  decompile (.decompile/AcMainTask_update.c). update() below is the touch/SE preamble
//  and the state dispatch; each state's inlined body is lifted into its own method as
//  it is reconstructed (see STUBS.md for which states remain).
//

#import "AcMainTask.h"

#include <new>

#import "AepManager.h"
#import "AudioManager.h"
#import "MainViewController.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"

// Ghidra: AcMainTask_ctor (FUN_00099ab0) — base C_TASK ctor, the arcade RNG
// constructed in place at +0x4f4, then the play-data block (already zeroed by
// m_playData's initialiser) and three sentinels (@ +0x508 = -1, +0x62c = -0x63,
// +0x5a0 = 3).
AcMainTask::AcMainTask() {
    new (&field<uint8_t>(0x4f4)) Random();   // FUN_00062b20: construct the arcade RNG
    field<int>(0x508) = -1;      // no drag anchor yet
    field<int>(0x62c) = -0x63;   // stored as 0xffffff9d
    field<int>(0x5a0) = 3;
}

// Ghidra: AcMainTask_update (FUN_00099d18). Snapshot the touches (recording a drag
// anchor and classifying a tap), refresh the "scrolled past the end" flag, then
// dispatch on the play-data state (@ +0x9f8).
void AcMainTask::update(int /*deltaMs*/) {
    neGraphics &gfx = neGraphics::shared();

    // Touch preamble (Ghidra: the touch loop at 0x99e34..0x99e92). Walk the live
    // touches until one is meaningful:
    //  * a held (valid) touch latches the drag anchor (@ +0x508/+0x50c/+0x510) if none
    //    is set, and marks a drag in progress;
    //  * a released touch that barely moved from its start point (< 11 on each axis,
    //    compared against the raw stored coordinates as the binary does) is a tap.
    m_frameDragging = false;
    m_frameTapped = false;
    m_frameTapTouch = nullptr;
    for (int i = 0, n = gfx.activeTouchCount(); i < n; i++) {
        const neTouchPoint *t = gfx.touchAt(i);
        if (t->valid != 0) {
            if (field<int>(0x508) < 0) {
                field<int>(0x508) = t->id;
                field<int>(0x50c) = (int)((float)t->x / 65536.0f);   // Ghidra: FixedToFP
                field<int>(0x510) = (int)((float)t->y / 65536.0f);
            }
            m_frameDragging = true;
            break;
        }
        if (t->released != 0) {
            int dx = t->x - t->startX;
            if (dx < 0) {
                dx = -dx;
            }
            if (dx > 10) {
                break;   // moved too far horizontally: not a tap
            }
            int dy = t->y - t->startY;
            if (dy < 0) {
                dy = -dy;
            }
            m_frameTapped = (dy < 11);
            m_frameTapTouch = t;
            break;
        }
    }

    // "Scrolled past the last row" flag (@ +0x5f2): list offset >= content bottom.
    field<bool>(0x5f2) = (int)field<short>(0x63c) <= field<int>(0x624);

    switch (state()) {
    case 0:
        stateInit();
        break;
    case 1:
        stateFadeIn();
        break;
    case 2:
        stateTreasureCheck();
        break;
    default:
        break;
    }
}

// case 0 — build the select/map scene, then start the BGM if a treasure record is
// present (subMapId @ +0x620 >= 0); otherwise take the no-treasure path. Ghidra: the
// case 0 body at 0x99e92 (FUN_0009fc90 then playBgm:0.5 / LAB_0009aa74).
void AcMainTask::stateInit() {
    setupScene();   // FUN_0009fc90
    if (field<short>(0x620) >= 0) {
        AudioManager *audio = [AudioManager sharedManager];
        [audio playBgm:0.5f];   // Ghidra: playBgm:, arg 0x3fe00000 == 0.5
    } else {
        field<bool>(0x5ee) = false;   // the binary jumps to LAB_0009aa74 (no-treasure)
    }
}

// case 1 — set a 30-frame fade-out and jump it to fully-faded, restore the menu BGM
// stack, push the sugoroku map-select screen, then advance to the treasure check.
// Ghidra: case 1 (FUN_00010698(scene,2) == playTransition(2,30,0), FUN_00010758(scene,0)).
void AcMainTask::stateFadeIn() {
    AepManager &aep = AepManager::shared();
    aep.playTransition(2, 30, 0);   // FUN_00010698(scene, 2): fade-out, 30 frames
    aep.setTransitionFrame(0);      // FUN_00010758(scene, 0): jump to fully-faded

    AudioManager *audio = [AudioManager sharedManager];
    if ([audio isPushBgm]) {
        [audio popBgm];
    }
    [audio playBgm:0.5f];

    MainViewController *root =
        (__bridge MainViewController *)neSceneManager::rootViewController();
    [root GotoMapSelect];   // -[MainViewController GotoMapSelect] @ 0xc7d8
    state() = 2;
}

// case 2 — read the temp-treasure record; if a sub-map is pending (subMapId >= 0),
// cache it (@ +0x620), load the map, and start play, else keep waiting. Ghidra: case 2
// (UserSettingData treasureTmp; FUN_000a0b58; playBgm at LAB_0009a026).
void AcMainTask::stateTreasureCheck() {
    TreasureTmpData tmp = [UserSettingData treasureTmp];
    field<short>(0x620) = tmp.subMapId;
    if (tmp.subMapId >= 0) {
        loadTreasureMap();   // FUN_000a0b58
        AudioManager *audio = [AudioManager sharedManager];
        [audio playBgm:0.5f];
    }
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
