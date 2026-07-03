//
//  BootLogoTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The boot logo
//  splash task's setup/state-machine/finish.
//

#import <Foundation/Foundation.h>

#import "AepManager.h"
#import "AppDelegate.h"
#import "BootLogoTask.h"
#import "TaskFactory.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neTextureForiOS.h"

// BootCreateNextTask comes from TaskFactory.h.

// Ghidra: BootLogoTask_ctor (FUN_0002af58) — base C_TASK ctor + zeroed fields.
BootLogoTask::BootLogoTask() = default;

// A touch that has been released this frame skips the current screen (Ghidra: the
// scan of NEGraphics's touch pool at the top of the update).
bool BootLogoTask::skipRequested() const {
    neGraphics &gfx = neGraphics::shared();
    int count = gfx.activeTouchCount();
    for (int i = 0; i < count; i++) {
        const neTouchPoint *t = gfx.touchAt(i);
        if (t != nullptr && t->released != 0) {
            return true;
        }
    }
    return false;
}

// Ghidra: BootLogoTask_setup (FUN_0002b1f4) — cache the render manager + screen
// scale, then load three device-sized branding PNGs into the sprites. The image
// set + on-screen size are chosen per display (iPad/Retina/phone); one confirmed
// resource stem is "eamusement_1024_2x" (the full per-device name tables live at
// the DAT_00130fd4.. constants).
void BootLogoTask::setup() {
    m_aep = &AepManager::shared();
    m_scale = neSceneManager::screenScale();

    // Choose the branding image set + canvas size for this display. Each set is the
    // three logos [konami, bemani, eamusement] at one resolution (real resource
    // names extracted from the DAT_00130fd4.. tables; the canvas size doubles as the
    // logo centre). The branch conditions mirror BootLogoTask_setup exactly: a
    // scene-manager device flag (DAT_00187b84) splits phone/pad, then displayType
    // (phone) or the screen scale (pad).
    NSArray<NSString *> *imageSet;
    const bool isPad = neSceneManager::isPadDisplay();   // DAT_00187b84 != 0
    if (!isPad) {
        if (AppDelegate.appDelegate.displayType == 2) {
            m_posX = 0x280; m_posY = 0x470;   // 640x1136 (4" retina)
            imageSet = @[ @"konami-568@2x", @"bemani640X1136@2x", @"eamusement-568@2x" ];
        } else {
            m_posX = 0x280; m_posY = 0x3c0;   // 640x960 (3.5" retina)
            imageSet = @[ @"konami@2x", @"bemani640X960@2x", @"eamusement@2x" ];
        }
    } else if (m_scale == 1.0f) {
        m_posX = 0x600; m_posY = 0x800;       // 1536x2048 (iPad retina)
        imageSet = @[ @"konami-1024@2x", @"bemani768X1024@2x", @"eamusement-1024@2x" ];
    } else {
        m_posX = 0x300; m_posY = 0x400;       // 768x1024 (iPad non-retina)
        imageSet = @[ @"konami-1024", @"bemani768X1024", @"eamusement-1024" ];
    }

    for (int i = 0; i < 3; i++) {
        m_logo[i] = new neTextureForiOS();
        NSString *path = [NSBundle.mainBundle pathForResource:imageSet[i] ofType:@"png"];
        m_logo[i]->load(path.UTF8String);
    }
}

// Draw one branding sprite centred at (m_posX, m_posY), full size/opacity, priority
// 5 (Ghidra: neTextureForiOS_draw FUN_0000fbcc as called from FUN_0002b4b4/b504).
void BootLogoTask::drawLogo(neTextureForiOS *logo) {
    if (logo == nullptr) {
        return;
    }
    neSpriteDrawParams p;
    p.x = m_posX;
    p.y = m_posY;
    p.w = 100;
    p.h = 100;
    p.color = 100;
    p.blend0 = 0x20;
    p.colorMul = 0xffffff;
    p.priority = 5;
    logo->draw(m_aep->orderingTable(), p);
}

// Ghidra: BootLogoTask_finish (FUN_0002b554) — log into Game Center, restore the
// screen scale, release the three sprites, kill this task, and spawn the next one.
void BootLogoTask::finish() {
    [AppDelegate.appDelegate loginGameCenter];
    neSceneManager::setScreenMetrics(neSceneManager::screenWidth(),
                                     neSceneManager::screenHeight(), m_scale);
    for (int i = 0; i < 3; i++) {
        delete m_logo[i];
        m_logo[i] = nullptr;
    }
    kill();   // +0x24 = 1: reaped on the next scheduler pass

    if (C_TASK *next = BootCreateNextTask()) {
        next->setPriority(3);
    }
}

// Ghidra: BootLogoTask_update (FUN_0002b02c) — the 10-state splash machine. Each
// screen fades in, holds ~kHoldFrames (or until a tap), then fades out; the three
// logos are shown in the order 0, 2, 1.
void BootLogoTask::update(int /*deltaMs*/) {
    const bool skip = skipRequested();

    switch (m_state) {
    case 0:
        setup();
        m_state = 1;
        break;
    case 1:
        m_aep->playTransition(1, kFirstFadeFrames, 0);   // fade in
        m_counter = 0;
        m_state = 2;
        break;
    case 2:   // hold logo 0
        if (skip) {
            m_counter = kHoldFrames;
        }
        if (m_aep->isTransitionDone()) {
            if (m_counter > 0x77) {
                m_aep->playTransition(2, kFadeFrames, 0);   // fade out
                m_state = 3;
            }
            m_counter++;
        }
        drawLogo(m_logo[0]);
        return;
    case 3:   // fade logo 0 out -> fade logo 2 in
        if (!m_aep->isTransitionDone()) {
            drawLogo(m_logo[0]);
            return;
        }
        m_aep->playTransition(1, kFadeFrames, 0);
        m_counter = 0;
        m_state = 4;
        break;
    case 4:   // hold logo 2
        if (skip) {
            m_counter = kHoldFrames;
        }
        if (m_aep->isTransitionDone()) {
            if (m_counter > 0x77) {
                m_aep->playTransition(2, kFadeFrames, 0);
                m_state = 5;
            }
            m_counter++;
        }
        drawLogo(m_logo[2]);
        return;
    case 5:   // fade logo 2 out -> fade logo 1 in
        if (!m_aep->isTransitionDone()) {
            drawLogo(m_logo[2]);
            return;
        }
        m_aep->playTransition(1, kFadeFrames, 0);
        m_counter = 0;
        m_state = 6;
        break;
    case 6:   // hold logo 1
        if (skip) {
            m_counter = kHoldFrames;
        }
        if (m_aep->isTransitionDone()) {
            if (m_counter > 0x77) {
                m_state = 7;
            }
            m_counter++;
        }
        drawLogo(m_logo[1]);
        return;
    case 7:   // fade logo 1 out
        m_aep->playTransition(2, kFadeFrames, 0);
        drawLogo(m_logo[1]);
        m_state = 8;
        break;
    case 8:
        if (!m_aep->isTransitionDone()) {
            drawLogo(m_logo[1]);
            return;
        }
        m_state = 9;
        break;
    case 9:
        finish();
        return;
    default:
        break;
    }
}
