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
#import "neDebugLog.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neTextureForiOS.h"

// BootCreateNextTask comes from TaskFactory.h.

// Ghidra: BootLogoTask_ctor (FUN_0002af58) — base ne::C_TASK ctor + zeroed fields.
BootLogoTask::BootLogoTask() = default;

// @ 0x2af8c — taskNode_deleteA is the compiler's deleting-destructor thunk
// (caSourceNode_dtor then operator delete). BootLogoTask frees its three
// sprites in finish(), so the real destructor only chains to the ne::C_TASK base —
// nothing to do here.
BootLogoTask::~BootLogoTask() = default;

// A touch that has been released this frame skips the current screen (Ghidra:
// the scan of NEGraphics's touch pool at the top of the update).
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

/**
 * BootLogoTask_setup — cache the render manager + screen scale, then load three
 * device-sized branding PNGs into the sprites. The image set + on-screen size are
 * chosen per display (iPad/Retina/phone); all twelve resource names were read
 * from the DAT_00130fd4.. CFString tables (pool @ 0x103779) and match exactly.
 * @ghidraAddress 0x2b1f4
 * @complete
 */
void BootLogoTask::setup() {
    m_aep = &AepManager::shared();
    // Ghidra: m_scale (+0x38) = g_uiScale — the saved half-scale (screenScale*0.5);
    // finish() restores it into orderingTable.flScreenHalfScale.
    m_scale = g_uiScale;

    // Boot logos render at native scale 1.0 (Ghidra: *(m_aep + 0x7c16e0) = 1.0f,
    // i.e. orderingTable.flScreenHalfScale); the saved m_scale is restored in finish().
    m_aep->orderingTable()->setRenderScale(1.0f);

    // Load the shared UI sound effects (Ghidra: neSeTable::loadSoundEffects @ 0x2c5c8).
    neSceneManager::shared().loadSystemSe();

    // Choose the branding image set + canvas size for this display. Each set is
    // the three logos [konami, bemani, eamusement] at one resolution (real
    // resource names extracted from the DAT_00130fd4.. tables; the canvas size
    // doubles as the logo centre). The branch conditions mirror
    // BootLogoTask_setup exactly: a scene-manager device flag (DAT_00187b84)
    // splits phone/pad, then displayType (phone) or the screen scale (pad).
    NSArray<NSString *> *imageSet;
    const bool isPad = neSceneManager::isPadDisplay(); // DAT_00187b84 != 0
    if (!isPad) {
        if (AppDelegate.appDelegate.displayType == 2) {
            m_posX = 0x280;
            m_posY = 0x470; // 640x1136 (4" retina)
            imageSet = @[ @"konami-568@2x", @"bemani640X1136@2x", @"eamusement-568@2x" ];
        } else {
            m_posX = 0x280;
            m_posY = 0x3c0; // 640x960 (3.5" retina)
            imageSet = @[ @"konami@2x", @"bemani640X960@2x", @"eamusement@2x" ];
        }
    } else if (m_scale == 1.0f) {
        m_posX = 0x600;
        m_posY = 0x800; // 1536x2048 (iPad retina)
        imageSet = @[ @"konami-1024@2x", @"bemani768X1024@2x", @"eamusement-1024@2x" ];
    } else {
        m_posX = 0x300;
        m_posY = 0x400; // 768x1024 (iPad non-retina)
        imageSet = @[ @"konami-1024", @"bemani768X1024", @"eamusement-1024" ];
    }

    for (int i = 0; i < 3; i++) {
        m_logo[i] = new neTextureForiOS();
        NSString *path = [NSBundle.mainBundle pathForResource:imageSet[i] ofType:@"png"];
        int rc = m_logo[i]->load(path.UTF8String);
        neDebugLog("BootLogoTask::setup logo[%d] name='%s' path=%s load=%d w=%d h=%d",
                   i,
                   imageSet[i].UTF8String,
                   path.UTF8String ? path.UTF8String : "(nil)",
                   rc,
                   m_logo[i]->width(),
                   m_logo[i]->height());
    }
    neDebugLog("BootLogoTask::setup isPad=%d displayType=%d scale=%.2f pos=(%d,%d)",
               (int)isPad,
               (int)AppDelegate.appDelegate.displayType,
               m_scale,
               m_posX,
               m_posY);
}

/**
 * Draw one branding sprite as a full-canvas quad at (0, 0) sized (m_posX,
 * m_posY), scale/colour 100, blend 0x20, colour-multiply 0x00ffffff, priority 5.
 * This is the shared body de-inlined from the two per-sprite wrappers; every
 * argument is bit-exact against their disassembly (the neTextureForiOS_draw call
 * at FUN_0000fbcc).
 * @ghidraAddress 0x2b4b4
 * @ghidraAddress 0x2b504
 * @complete
 */
void BootLogoTask::drawLogo(neTextureForiOS *logo) {
    if (logo == nullptr) {
        return;
    }
    // Bit-exact args from the drawLogo disasm (@ 0x2b504 / 0x2b4b4): the sprite
    // draw is neTextureForiOS::draw(pAep, tex, u=0, v=0, nDrawX, nDrawY, 0, 0, 100,
    // 100, 0, 0, 0, 100, 0, 0x20, 0x00ffffff, 0, 5, 0). Mapped onto the sprite
    // params: full-canvas quad at the origin (w/h = m_posX/m_posY = device canvas),
    // scale 100, colour 100, blend 0x20, colour-mul 0x00ffffff, priority 5. Zero
    // args map to the fields that default to 0 (offset / uv-key).
    neSpriteDrawParams p;
    p.x = 0;
    p.y = 0;
    p.w = m_posX;
    p.h = m_posY;
    p.sx = 100;
    p.sy = 100;
    p.color = 100;
    p.blend0 = 0x20;
    p.colorMul = 0xffffff;
    p.priority = 5; // logos in bucket 5; the fade overlay sits in bucket 1 -> on top
    if (NE_DBG_FIRST(120)) {
        neDebugLog("BootLogoTask::drawLogo logo=%p w=%d h=%d canvas=(%d,%d)",
                   (void *)logo,
                   logo->width(),
                   logo->height(),
                   m_posX,
                   m_posY);
    }
    logo->draw(m_aep->orderingTable(), p);
}

/**
 * BootLogoTask_drawLogo1 — the per-screen draw wrapper the state machine calls to
 * blit the second branding sprite (m_logo[1], @ +0x30); just drawLogo() bound to
 * that sprite.
 * @ghidraAddress 0x2b504
 * @complete
 */
void BootLogoTask::drawLogo1() {
    drawLogo(m_logo[1]);
}

/**
 * BootLogoTask_drawLogo2 — the per-screen draw wrapper for the third branding
 * sprite (m_logo[2], @ +0x34); drawLogo() bound to that sprite.
 * @ghidraAddress 0x2b4b4
 * @complete
 */
void BootLogoTask::drawLogo2() {
    drawLogo(m_logo[2]);
}

/**
 * Ghidra: BootLogoTask_finish (FUN_0002b554) — log into Game Center, restore
 * the screen scale, release the three sprites, kill this task, and spawn the
 * next one (TitleTask).
 * @complete
 */
void BootLogoTask::finish() {
    [AppDelegate.appDelegate loginGameCenter];
    // Ghidra: orderingTable.flScreenHalfScale = m_scale — restore the saved UI half-scale.
    m_aep->orderingTable()->setRenderScale(m_scale);
    for (int i = 0; i < 3; i++) {
        delete m_logo[i];
        m_logo[i] = nullptr;
    }
    kill(); // +0x24 = 1: reaped on the next scheduler pass

    if (ne::C_TASK *next = BootCreateNextTask()) {
        next->setPriority(3);
    }
}

/**
 * Ghidra: BootLogoTask_update (FUN_0002b02c) — the 10-state splash machine.
 * Each screen fades in, holds ~kHoldFrames (or until a tap), then fades out;
 * the three logos are shown in the order 0, 2, 1.
 * @complete
 */
void BootLogoTask::update(int /*deltaMs*/) {
    const bool skip = skipRequested();

    switch (m_state) {
    case 0:
        setup();
        m_state = 1;
        break;
    case 1:
        m_aep->playTransition(1, kFirstFadeFrames, 0); // fade in
        m_counter = 0;
        m_state = 2;
        break;
    case 2: // hold logo 0
        if (skip) {
            m_counter = kHoldFrames;
        }
        if (m_aep->isTransitionDone()) {
            if (m_counter > 0x77) {
                m_aep->playTransition(2, kFadeFrames, 0); // fade out
                m_state = 3;
            }
            m_counter++;
        }
        drawLogo(m_logo[0]);
        return;
    case 3: // fade logo 0 out -> fade logo 2 in
        if (!m_aep->isTransitionDone()) {
            drawLogo(m_logo[0]);
            return;
        }
        m_aep->playTransition(1, kFadeFrames, 0);
        m_counter = 0;
        m_state = 4;
        break;
    case 4: // hold logo 2
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
        drawLogo2();
        return;
    case 5: // fade logo 2 out -> fade logo 1 in
        if (!m_aep->isTransitionDone()) {
            drawLogo2();
            return;
        }
        m_aep->playTransition(1, kFadeFrames, 0);
        m_counter = 0;
        m_state = 6;
        break;
    case 6: // hold logo 1
        if (skip) {
            m_counter = kHoldFrames;
        }
        if (m_aep->isTransitionDone()) {
            if (m_counter > 0x77) {
                m_state = 7;
            }
            m_counter++;
        }
        drawLogo1();
        return;
    case 7: // fade logo 1 out
        m_aep->playTransition(2, kFadeFrames, 0);
        drawLogo1();
        m_state = 8;
        break;
    case 8:
        if (!m_aep->isTransitionDone()) {
            drawLogo1();
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
