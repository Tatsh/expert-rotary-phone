//
//  PlayJudge.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (FUN_0002f1f8). The per-frame play/judge pass of the standard-mode main
//  task.
//
//  This carries the full judge control flow, addressing every note by its pool
//  id (the render descriptor's noteId): for each still-judgeable active note it
//  looks up (or allocates) the note's judge state, seeds the approach animation,
//  hit-tests the current touches against the note's judge-line target, dispatches
//  fresh taps to NoteMng::judgeNoteHit and re-taps to judgeHold (or auto-judges
//  in demo mode), tracks long-note holds by the bound finger via neGraphics,
//  drives the lane-kind-specific phase/gauge machine, retires resolved notes
//  (setLaneFlag + slot free), and drives the combo-milestone burst + sustained
//  combo-effect AepLyrCtrl layers.
//
//  The full draw region is reconstructed from the armv7 disassembly of
//  FUN_0002f1f8 (the decompiler garbles the NEON): the note's scroll-progress
//  interpolation from spawn position to the judge-line target, the per-phase
//  animation frame, the head/tail note sprite, the judge-result/base/EFF_HIT
//  effect sprites, the CD-jacket, and the long-note connecting bar (drawAepFrameEx
//  with an atan2 rotation + a fade over 3000 ms whose length is
//  fade*barLenScale + barLenBase). Every drawLayer/drawAepFrameEx argument tuple
//  was resolved by disassembling the callee (0xfd64 / AepDrawSpriteHandle) and
//  matching its arg reads to the caller's stack pushes.
//

#import "PlayJudge.h"

#include <cmath> // lroundf, fmod (note frame), atan2/cos/sin (long-note bar angle)
#include <span>

#import <Foundation/Foundation.h>

#import "AepFrameDraw.h"
#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "NoteMng.h"
#import "PlayTask.h"
#import "neDebugLog.h"
#import "neGraphics.h"

// --- Play-data field access -------------------------------------------------
// The play data is the standard-mode play task, PlayTask; the judge reaches its
// named members directly, so the field reads/writes below are plain member
// access.
namespace {

// The combo-milestone burst layers only restart while the play is live and the
// hit-effect option is on (Ghidra: the milestone if/else chain is wrapped in
// playData+0x9c9==0 && +0x9e5!=0 && +0x9e7==0 && +0x9ca==0).
inline bool comboBurstEnabled(const PlayTask *p) {
    return !p->m_isDemoPlay && p->m_optEffectOn && !p->m_optOldHardware && !p->m_isPadDisplay;
}

constexpr int kJudgeStateCount = 60; // Ghidra: FUN_0003126c loop bound 0x3c

// Note flag bits, as the draw/judge pass reads them off the render descriptor.
// These are the same ActiveNote flags NoteMng sets (see NoteFlag in NoteMng.h),
// named here for the render context: kFlagJudged 0xc0 = LANE_HELD|HANDLED,
// kFlagInactive 0x20 = MISSED, kFlagGraded 0x2f = any grade result (RESOLVED),
// kFlagHold 0x300 = LONG_DONE, kFlagHoldOK/Fail 0x100/0x200 = LONG_SUCCESS/FAILED.
constexpr uint16_t kFlagJudged = 0xc0;    // already resolved -> skip
constexpr uint16_t kFlagInactive = 0x20;  // not yet / no longer on the judge field
constexpr uint16_t kFlagGraded = 0x2f;    // has a grade result (good/great/cool/bad/missed)
constexpr uint16_t kFlagHold = 0x300;     // long-note span bits
constexpr uint16_t kFlagHoldOK = 0x100;   // hold completed
constexpr uint16_t kFlagHoldFail = 0x200; // hold broken

// Combo-milestone tracking global (Ghidra: DAT_00179000). The current combo the
// milestone jingles react to.
// (Read through NoteMng below; kept here for the milestone thresholds.)

// Ghidra: FUN_0003126c — find the judge state for pool note `noteId`, or claim a
// free slot and initialise it. Returns nullptr if the pool is full.
NoteJudgeState *judgeStateFor(PlayTask *playData, unsigned noteId) {
    NoteJudgeState *pool = playData->m_judgePool; // the +0x3c8 pool
    NoteJudgeState *freeSlot = nullptr;
    for (int i = 0; i < kJudgeStateCount; ++i) {
        NoteJudgeState *s = &pool[i];
        if (s->noteId == noteId) {
            return s;
        }
        // A free slot is sentinelled with -1 (PlayTask init stamps noteId =
        // 0xffffffff), NOT 0 — the binary tests the field as a signed int `< 0`.
        // Testing == 0 here would match pool slot 0 and report the pool exhausted
        // on a freshly-reset pool (every slot is -1).
        if (freeSlot == nullptr && static_cast<int32_t>(s->noteId) < 0) {
            freeSlot = s;
        }
    }
    if (freeSlot != nullptr) {
        freeSlot->noteId = noteId;
        freeSlot->phase = 0;
        freeSlot->result = -1;
        freeSlot->timestamp = 0;
        freeSlot->touchId = -1;
        return freeSlot;
    }
    return nullptr;
}

// Whether the play is in demo/auto-judge mode (Ghidra: DAT_00187b59).
bool g_autoPlay = false; // extern flag in the binary; false in normal play

// Ghidra: FUN_000312cc — apply a resolved note's judge result to the life gauge
// (+0x9c0), clamped to [0, 0x400]. A GREAT/COOL (result 2/3) adds
// gaugeGainGreat, a GOOD (result 1) adds gaugeGainGood, and a BAD/miss (result
// 0) adds gaugeLossMiss (a negative delta) and raises the miss flag (+0x9dc).
// Any other result leaves the value unchanged and only re-clamps. The binary
// accumulates in fixed->float->fixed; modelled here as a float add + round.
void updateGaugeValue(PlayTask *playData, int result) {
    int gauge = playData->m_gaugeValue;
    if (result == 2 || result == 3) {
        gauge = static_cast<int>(lroundf(static_cast<float>(gauge) + playData->m_gaugeGainGreat));
    } else if (result == 0) {
        playData->m_damagedThisFrame = true;
        gauge = static_cast<int>(lroundf(static_cast<float>(gauge) + playData->m_gaugeLossMiss));
    } else if (result == 1) {
        gauge = static_cast<int>(lroundf(static_cast<float>(gauge) + playData->m_gaugeGainGood));
    }
    if (gauge < 1) {
        gauge = 0;
    }
    if (gauge > 0x400) {
        gauge = 0x400;
    }
    playData->m_gaugeValue = static_cast<int16_t>(gauge);
}

} // namespace

// Ghidra: DAT_0002f67c (0x4184cccd = 16.6f) — the note-sprite animation step, in
// milliseconds. The current animation frame is the time elapsed since the phase
// started divided by this; the judge retires a note once its frame reaches the
// phase's length.
static constexpr float kFrameStepMs = 16.6f;

namespace {

// Ghidra: the retire-timestamp offset folded into FUN_0002f1f8's tail. A SPECIAL
// note (renderKind 1) that lapses in phase 1 has its release timestamp pushed out
// by (graphic - holdJudge) tap windows (0x118 = 280 ms each); a non-positive
// difference (as a signed byte) still waits one window. The binary computes
// (graphic - holdJudge) << 24 and tests the sign, i.e. an int8 comparison.
inline int specialLapseOffset(int graphic, unsigned holdJudge) {
    const int8_t d = static_cast<int8_t>(graphic - static_cast<int>(holdJudge));
    return d <= 0 ? 0x118 : static_cast<int>(d) * 0x118 + 0x118;
}

} // namespace

// Ghidra: FUN_0002f1f8.
void PlayTask::playJudgeUpdate(std::span<const float> touchXY, std::span<const int> touchIds) {
    const auto touchCount = touchIds.size();
    NoteMng &nm = NoteMng::shared();
    neGraphics &gfx = neGraphics::shared();
    AepManager &aep = AepManager::shared(); // note-sprite draws go through the ordering table

    // Snapshot the touch points (a fixed 8-pair / 0x40-byte block); a negative
    // coordinate marks an empty/consumed slot. The original memsets 0xff (a NaN,
    // which fails the `>= 0` live-touch test just like a negative) when there is
    // no touch array, else copies the whole block verbatim.
    constexpr int kMaxTouches = 8;
    float xy[kMaxTouches * 2];
    for (int i = 0; i < kMaxTouches * 2; ++i) {
        xy[i] = !touchXY.empty() ? touchXY[i] : -1.0f;
    }

    const float beat = NoteBeatIntervalMs(); // Ghidra: GetBeatInterval (extraout_r0)
    const int curTime = nm.getCurrentPosition();
    const int noteCount = nm.getActiveNoteCount();
    const float scale = m_uiScale;
    const float radius = m_hitRadius;
    const bool autoJudge = g_autoPlay;  // Ghidra: DAT_00187b59
    const bool stopping = m_state == 5; // Ghidra: this+0x9fc == 5

    bool judgedAny = false; // Ghidra bVar4: a tap/auto hit graded positive this frame
    bool holdEnded = false; // Ghidra bVar5: a long note completed this frame
    auto boundCount = 0uz;  // Ghidra nBoundCount: fingers bound in non-spatial mode

    // Walk active notes nearest-the-judge-line last (high index -> low), so one
    // tap resolves the closest matching note.
    for (int index = noteCount - 1; index >= 0; --index) {
        NoteRenderData note;
        nm.getNoteObject(&note, index);
        if ((note.flags & kFlagJudged) != 0) {
            continue; // already fired / not judgeable
        }

        NoteJudgeState *st = judgeStateFor(this, note.noteId);
        if (st == nullptr) {
            continue; // pool full (should not happen once the pool is freed at init)
        }

        // Seed the animation timestamp to the beat boundary at or before now,
        // counting back from the note's own time (drives the approach animation).
        if (st->timestamp == 0) {
            float t = static_cast<float>(note.startTick);
            do {
                t -= beat;
            } while (static_cast<float>(curTime) < t);
            st->timestamp = static_cast<int>(lroundf(t));
        }

        unsigned holdJudge = note.spawnKind; // Ghidra dwHoldJudge: hold-tap count

        // Approach -> active: once the note is within one beat of the judge line,
        // enter phase 1 and re-anchor the animation one beat before the note time.
        if (st->phase == 0 && static_cast<float>(static_cast<int>(
                                  note.startTick - static_cast<unsigned>(curTime))) <= beat) {
            st->phase = 1;
            st->timestamp = static_cast<int>(lroundf(static_cast<float>(note.startTick) - beat));
        }

        const bool onField = (note.flags & kFlagInactive) == 0;

        // --- Judge / hit-test -------------------------------------------------
        // Judge this note if it is on the field and still open: either unresolved
        // (a fresh tap) or a SPECIAL note (renderKind 1) with taps remaining (a
        // re-tap that feeds judgeHold).
        if (onField && (st->result < 0 || (note.renderKind == NOTE_RENDER_SPECIAL &&
                                           static_cast<int8_t>(note.spawnKind) > 0))) {
            if (!autoJudge) {
                if (touchCount > 0) {
                    if (!m_optSimpleMode) {
                        // Distance-test each live touch against the judge-line target.
                        for (auto t = 0uz; t < touchCount; ++t) {
                            const float tx = xy[t * 2];
                            const float ty = xy[t * 2 + 1];
                            if (tx < 0.0f || ty < 0.0f) {
                                continue; // consumed / empty
                            }
                            // The judge target is the intersection the two buttons
                            // converge on -- note.hitX/hitY. The binary tests the
                            // touch against local_bc[4]/local_a8 (Ghidra 0x2f4c0),
                            // the reordered hit point, not a button start.
                            const float dx = note.hitX - tx / scale;
                            const float dy = note.hitY - ty / scale;
                            if (dx * dx + dy * dy < radius * radius) {
                                if (st->result < 0) {
                                    st->result = nm.judgeNoteHit(note.noteId);
                                } else {
                                    holdJudge = static_cast<unsigned>(nm.judgeHold(
                                        note.noteId, static_cast<unsigned>(st->result)));
                                }
                                judgedAny = judgedAny || st->result > 0;
                                if (st->result >= 0) {
                                    xy[t * 2] = -1.0f; // consume the touch
                                    xy[t * 2 + 1] = -1.0f;
                                    ++boundCount;
                                    if (!touchIds.empty()) {
                                        st->touchId = touchIds[t]; // bind the finger
                                    }
                                    break;
                                }
                            }
                        }
                    } else if (boundCount < touchCount) {
                        // Non-spatial mode: consume touches in order.
                        if (st->result < 0) {
                            st->result = nm.judgeNoteHit(note.noteId);
                        } else {
                            holdJudge = static_cast<unsigned>(
                                nm.judgeHold(note.noteId, static_cast<unsigned>(st->result)));
                        }
                        judgedAny = judgedAny || st->result > 0;
                        if (st->result >= 0) {
                            if (!touchIds.empty()) {
                                st->touchId = touchIds[boundCount];
                            }
                            ++boundCount;
                        }
                    }
                }
            } else if ((note.flags & kFlagGraded) != 0) {
                st->result = 3; // demo mode auto-judges to COOL
                judgedAny = true;
            }
        }

        // The flags the phase machine works from: normally the note's own, but a
        // long-note update below replaces them with its result bits (Ghidra
        // local_110).
        unsigned noteFlags = note.flags;

        // --- Long-note hold tracking -----------------------------------------
        // Only for a LONG note (renderKind 2) still spanning the judge line with
        // its outcome not yet latched: while the bound finger has lifted, advance
        // the hold and record whether it broke (0x200) or completed (0x100).
        if (!stopping && onField && note.renderKind == NOTE_RENDER_LONG &&
            (note.flags & kFlagGraded) != 0 && (note.flags & kFlagHold) == 0) {
            const bool fingerUp = st->touchId == -1 || gfx.findTouchById(st->touchId) == nullptr;
            if (fingerUp) {
                const unsigned r = static_cast<unsigned>(nm.updateLongNote(note.noteId));
                if ((r & 0xffff) != 0) {
                    noteFlags = r;
                    if (r & kFlagHoldFail) {
                        st->phase = 2;
                        st->result = 0;
                        st->timestamp = curTime;
                    } else if (r & kFlagHoldOK) {
                        st->result = (r & 4) ? 3 : (r & 2) ? 2 : 1;
                    }
                }
            }
        }

        // --- Resolved-note phase advance -------------------------------------
        // A resolved note advances to a display phase and feeds its result into
        // the life gauge, but WHEN depends on the render kind: a NORMAL note
        // advances immediately; a SPECIAL note waits until its hold-tap count
        // reaches zero; a LONG note waits until its tail passes with the span bits
        // still latched (and that completion arms the touch SE, holdEnded).
        if (st->result >= 0) {
            bool advance = false;
            bool longComplete = false; // Ghidra cVar7 == 2
            switch (note.renderKind) {
            case NOTE_RENDER_NORMAL:
                advance = true;
                break;
            case NOTE_RENDER_LONG:
                if (note.endTick <= static_cast<unsigned>(curTime) &&
                    (noteFlags & kFlagHold) != 0) {
                    advance = true;
                    longComplete = true;
                }
                break;
            case NOTE_RENDER_SPECIAL:
                if ((holdJudge & 0xff) == 0) {
                    advance = true;
                }
                break;
            }
            if (advance && st->phase < 2) {
                if (st->result == 0) {
                    st->phase = 2; // BAD -> miss display
                } else {
                    st->phase = 3; // hit display
                    holdEnded = holdEnded || longComplete;
                }
                st->timestamp = curTime;
                updateGaugeValue(this, st->result);
            }
        }

        // --- Draw the note sprite --------------------------------------------
        // Reconstructed from the armv7 disassembly of FUN_0002f1f8's draw region
        // (the decompiler garbles the NEON; this is derived from the register ops
        // and the float pool at DAT_0002f67c..0x2f690 = {16.6, 1024.0, 1/1024,
        // 100.0, 3000.0, 180.0}). AepManager::drawLayer takes integer positions
        // (soft-float ABI); its argument slots were resolved by disassembling the
        // callee (0xfd64) and matching its r7-relative arg reads to the caller's
        // stack setup at 0x2f818.

        // Elapsed animation frames (~16.6 ms each): the retire path keys on this.
        int nFrameNo = static_cast<int>(static_cast<float>(curTime - st->timestamp) / kFrameStepMs);
        if (nFrameNo < 0) {
            nFrameNo = 0;
        }

        // The note-sprite animation frame (Ghidra iVar15) is phase-specific: a
        // resolved note (phase 2/3) uses the elapsed frame; phase 1 eases toward the
        // layer's last frame over one beat (0x2f6ea); phase 0 pulses with the beat
        // (0x2f714) — on odd half-beats it sweeps the layer by the fractional beat
        // position (fmod of the animation time over the beat), even half-beats hold
        // frame 0.
        int noteFrame;
        if (st->phase == 1) {
            const int last = m_toneJudgeFrames[1] - 1;
            noteFrame =
                static_cast<int>(static_cast<float>((curTime - st->timestamp) * last) / beat);
            if (noteFrame > last) {
                noteFrame = last;
            }
        } else if (st->phase == 0) {
            const int anchor =
                static_cast<int>(static_cast<float>(note.startTick) - 0.5f * beat) - curTime;
            const int halfBeats =
                static_cast<int>(static_cast<float>(static_cast<unsigned>(anchor)) / beat);
            if (halfBeats & 1) {
                const float ph =
                    std::fmod(0.5f * beat + static_cast<float>(curTime - st->timestamp), beat);
                noteFrame =
                    static_cast<int>(ph * static_cast<float>(m_toneJudgeFrames[0] - 1) / beat);
            } else {
                noteFrame = 0;
            }
        } else {
            noteFrame = nFrameNo;
        }

        // The note travels from its spawn position to the judge-line target as it
        // scrolls in: progress runs 0 -> 1 as flScrollStart falls 1024 -> 0 (Ghidra:
        // DAT_0002f680 = 1024.0, DAT_0002f684 = 1/1024). Each note draws two points,
        // its head (x/y) and tail (x2/y2), both toward the same judge target — a tap
        // (head == tail) draws one sprite, a long note stretches head-to-tail. The
        // draw is gated on the note frame being within the phase layer's length.
        if (noteFrame < m_toneJudgeFrames[st->phase]) {
            // progress is CAPPED at 1: the binary holds the interp factor at 1024
            // (vmin.f32 d11, d11, d11 - flScrollStart @0x2f7ae, with d11 = 1024.0), so
            // once flScrollStart passes 0 the note -- and its anchored hold bar --
            // freeze at the intersection instead of extrapolating past it. Only the
            // lower bound (pre-spawn) stays unclamped.
            const float scrollNum = 1024.0f - note.scrollStart;
            const float progress = (scrollNum < 1024.0f ? scrollNum : 1024.0f) / 1024.0f;
            const int noteLayer = m_toneJudgeLyr[st->phase]; // +0xc4[phase]
            const int drawScale = m_popkunSize;              // +0x9bc
            // Each note is two buttons that fly in from opposite sides and meet at
            // the intersection -- the hit target. copyNoteRenderData (Ghidra
            // 0x34758) reorders the six position floats, so the per-frame draw
            // (0x2f7xx) uses buttonA/buttonB as the two incoming buttons and the
            // hit point -- the byte[0xe] plain-percentage field with no +150/-75
            // edge offset -- as the fixed intersection both converge on. The two
            // buttons are authored equidistant from the intersection, so with the
            // same progress they approach from opposite sides at matching speed.
            const float hitX = note.hitX;
            const float hitY = note.hitY;
            for (int pt = 0; pt < 2; ++pt) {
                const float nx = (pt == 0) ? note.buttonAX : note.buttonBX;
                const float ny = (pt == 0) ? note.buttonAY : note.buttonBY;
                const int screenX = static_cast<int>(nx + progress * (hitX - nx));
                const int screenY = static_cast<int>(ny + progress * (hitY - ny));
                // Arg values resolved from the caller's stack push (0x2f818) mapped
                // onto drawLayer via the callee's r7-relative reads (0xfd64): layer,
                // frame, integer x/y, scale on both axes, then the constant tuple
                // {0, 150, 150, 100, 0, 1, 0x20, -1} with the note's own layer id in
                // the draw-context slot.
                // Ghidra 0x2f7fe..0x2f87e (arg stack setup for drawLayer @0xfd64):
                // anchorX=150 (sp+0x10), anchorY=150 (sp+0x14), color=100 (sp+0x18,
                // full brightness), colorHi=0 (sp+0x1c), loopFlags=1 (sp+0x20),
                // blend=0x20, colorRGB=0xffffffff, clip/context=0, priority=*st,
                // visFlag=0. The reconstruction had anchorY/color/colorHi/loopFlags
                // shifted, passing color=0 -- every note sprite drew at zero
                // brightness, i.e. invisible.
                aep.drawLayer(noteLayer,
                              noteFrame,
                              screenX,
                              screenY,
                              drawScale,
                              drawScale,
                              0,
                              150,
                              150,
                              100,
                              0,
                              1,
                              0x20,
                              0xffffffff,
                              nullptr,
                              nullptr,
                              st->layerId,
                              0);

                // Long-note connecting bar: for a LONG note whose span is still
                // open, draw the bar sprite along the note->judge-line direction,
                // its length growing with the fade over 3000 ms. Ghidra:
                // 0x2f888..0x2fa6e (drawAepFrameEx segments 0x2fa16 / 0x2fa6a; the
                // (cos,sin) offset uses len = fade*barLenScale + barLenBase, and the
                // angle is atan2(dy,dx) with the +/-90 table for the vertical case).
                if (note.renderKind == NOTE_RENDER_LONG && (noteFlags & kFlagHold) == 0) {
                    int span = static_cast<int>(note.endTick) - curTime;
                    const int full =
                        static_cast<int>(note.endTick) - static_cast<int>(note.startTick);
                    if (full < span) {
                        span = full;
                    }
                    const float fade =
                        span < 1 ? 0.0f : (span > 2999 ? 1.0f : static_cast<float>(span) / 3000.0f);

                    const int dx = static_cast<int>(nx - hitX);
                    const int dy = static_cast<int>(ny - hitY);
                    const double angleRad =
                        (dx == 0) ? (dy < 0 ? -M_PI_2 : M_PI_2) :
                                    std::atan2(static_cast<double>(dy), static_cast<double>(dx));
                    const int angleDeg = static_cast<int>(angleRad * 180.0 / M_PI);
                    const float len =
                        fade * static_cast<float>(m_barLenScale) + static_cast<float>(m_barLenBase);
                    const int prio = m_barPriority / 2;

                    // The bar BODY sprite is the wide TONE_L1_2 (m_pauseEyeToneFrm[6],
                    // atlas 1638x118) -- or the pressed TONE_L1_2_PUSH
                    // (m_pauseEyeToneFrm[7]) while the button is actively held. Ghidra
                    // 0x2f7d0-0x2f7d4 selects the body handle: play+0x214 (TONE_L1_2)
                    // when (flags & 0x300) != 0 or (flags & 0x2f) == 0, else play+0x218
                    // (TONE_L1_2_PUSH). It is NOT m_barSegFrame (+0x21c = TONE_L1_2_LIGHT,
                    // the 170x178 glow the cap segment draws): drawing that 170-wide tile
                    // as the body was the "tiny grey ellipse" bug.
                    const int barBodyFrame =
                        ((noteFlags & kFlagHold) != 0 || (noteFlags & kFlagGraded) == 0) ?
                            m_pauseEyeToneFrm[6] // TONE_L1_2 (+0x214), the wide bar
                            :
                            m_pauseEyeToneFrm[7]; // TONE_L1_2_PUSH (+0x218)

                    // Temporary NE_DBG trace to diagnose why the hold bar body does
                    // not render on device (idevicesyslog). Logs the inputs to both
                    // bar-segment draws once per button per frame.
                    NE_DBG(neDebugLog(
                        "holdbar pt=%d kind=%d flags=0x%x fade=%.3f bodyScaleX=%d capDrawn=%d "
                        "notePos=(%d,%d) ang=%d hit=(%.0f,%.0f) btn=(%.0f,%.0f) capFrame=%d "
                        "bodyFrame=%d lenScale=%d lenBase=%d segLyr1=%d",
                        pt,
                        note.renderKind,
                        noteFlags,
                        static_cast<double>(fade),
                        static_cast<int>(fade * 100.0f),
                        fade > 0.0f ? 1 : 0,
                        screenX,
                        screenY,
                        angleDeg,
                        static_cast<double>(hitX),
                        static_cast<double>(hitY),
                        static_cast<double>(nx),
                        static_cast<double>(ny),
                        m_barSegFrame,
                        barBodyFrame,
                        m_barLenScale,
                        m_barLenBase,
                        m_barSegLyr1));

                    if (fade > 0.0f) {
                        const int bx = screenX + static_cast<int>(
                                                     len * static_cast<float>(std::cos(angleRad)));
                        const int by = screenY + static_cast<int>(
                                                     len * static_cast<float>(std::sin(angleRad)));
                        drawAepFrameEx(&aep,
                                       m_barSegFrame,
                                       bx,
                                       by,
                                       100,
                                       100,
                                       angleDeg,
                                       0,
                                       prio,
                                       100,
                                       0,
                                       0x200,
                                       0xffffffff,
                                       nullptr,
                                       21,
                                       2);
                    }
                    // The second segment is the bar BODY (barBodyFrame, the wide
                    // TONE_L1_2 / TONE_L1_2_PUSH selected above), drawn from the note
                    // toward the judge line and scaled along its length by `fade` so it
                    // drains as the hold plays, at a fixed thickness. Ghidra 0x2fa6a:
                    // handle = *[sp+0xc8] (the body frame, not m_barSegFrame), scaleX =
                    // fade*100 (a percentage; 0x2fa24 multiplies fade by d15, and d15 =
                    // [0x2f688] = 100.0, NOT the bar length `len`), scaleY = 100 (fixed
                    // thickness), anchorY = m_barSegLyr1/2. `len` positions the cap only,
                    // never scales the body. m_barSegLyr1 (+0x99c) is NOT a layer id; it
                    // is this segment's anchorY source.
                    const int seg2Scale = static_cast<int>(fade * 100.0f);
                    drawAepFrameEx(&aep,
                                   barBodyFrame,
                                   screenX,
                                   screenY,
                                   seg2Scale,
                                   100,
                                   angleDeg,
                                   0,
                                   m_barSegLyr1 / 2,
                                   100,
                                   0,
                                   0x200,
                                   0xffffffff,
                                   nullptr,
                                   21,
                                   2);
                }

                // CD-jacket overlay at the note head (pt 0) when enabled and the
                // note is on the field but not yet spanning its hold: layer
                // effectStateLyr[12] (+0x114), frame cdFrame (+0x3c4), at the note's
                // interp position. Args traced at 0x2fa8c (blend 0x200, context 16).
                if (pt == 0 && m_optLongNoteEffect && (noteFlags & kFlagGraded) != 0 &&
                    (noteFlags & kFlagHold) == 0) {
                    const int effScale = m_hitEffectScale / 2;
                    aep.drawLayer(m_effectStateLyr[12],
                                  m_cdFrame,
                                  screenX,
                                  screenY,
                                  drawScale,
                                  drawScale,
                                  0,
                                  effScale,
                                  effScale,
                                  100,
                                  0,
                                  1,
                                  0x200,
                                  0xffffffff,
                                  nullptr,
                                  nullptr,
                                  16,
                                  0);
                }
            }
        }

        // --- Hit-effect flashes at the judge line ----------------------------
        // These overlay sprites flash at the judge-line target: EFF_HIT while the
        // note is active (phase 1), the GOOD/GREAT/COOL result burst, and the
        // GG_HANTEI base underlay. Layers / frame lengths come from
        // effectStateLyr/effectStateFrames; positions are the integer judge target;
        // effScale = hitEffectScale/2. Arg tuples and gates traced from the
        // drawLayer callee (0xfd64) against the caller pushes at 0x2fb16 (hit),
        // 0x2fbe2 (burst), 0x2fce0 (base), and the branch tangle 0x2fb84..0x2fce8.
        // The judge-line effects flash at the intersection (note.hitX/hitY =
        // local_bc[4]/local_a8 in the binary), not at a button start.
        const int hx = static_cast<int>(note.hitX);
        const int hy = static_cast<int>(note.hitY);
        const int effScale = m_hitEffectScale / 2; // +0x9e0

        if (st->phase == 1 && noteFrame < m_effectStateFrames[1]) {
            aep.drawLayer(m_effectStateLyr[1],
                          noteFrame,
                          hx,
                          hy,
                          100,
                          100,
                          0,
                          effScale,
                          effScale,
                          100,
                          0,
                          1,
                          0x20,
                          0xffffffff,
                          nullptr,
                          nullptr,
                          20,
                          0);
        }

        if (st->result >= 0) {
            const int hitScale = m_popkunSize; // +0x9bc
            // Whether the GOOD/GREAT/COOL burst shows for this render kind (0x2fb84):
            // a SPECIAL note only once its hold-tap count is exhausted, a LONG note
            // only with its hold-completed bit set.
            const bool showBurst =
                note.renderKind == NOTE_RENDER_NORMAL ||
                (note.renderKind == NOTE_RENDER_SPECIAL && (holdJudge & 0xff) == 0) ||
                (note.renderKind == NOTE_RENDER_LONG && (noteFlags & kFlagHoldOK) != 0);
            if (showBurst && st->result >= 1 && st->result <= 3 &&
                nFrameNo < m_effectStateFrames[st->result + 1]) {
                aep.drawLayer(m_effectStateLyr[st->result + 1],
                              nFrameNo,
                              hx,
                              hy,
                              hitScale,
                              hitScale,
                              0,
                              effScale,
                              effScale,
                              100,
                              0,
                              1,
                              0x20,
                              0xffffffff,
                              nullptr,
                              nullptr,
                              15,
                              0);
            }

            // The GG_HANTEI base underlay (0x2fc54): a SPECIAL BAD fully consumed by
            // its hold, or a LONG note without span bits, drops straight to retire.
            const bool showBase =
                note.renderKind == NOTE_RENDER_NORMAL ||
                (note.renderKind == NOTE_RENDER_SPECIAL &&
                 ((holdJudge & 0xff) == 0 || st->result != 0)) ||
                (note.renderKind == NOTE_RENDER_LONG && (noteFlags & kFlagHold) != 0);
            if (showBase && nFrameNo < m_effectStateFrames[0]) {
                aep.drawLayer(m_effectStateLyr[0],
                              nFrameNo,
                              hx,
                              hy,
                              hitScale,
                              hitScale,
                              0,
                              0,
                              0,
                              100,
                              0,
                              1,
                              0x20,
                              0xffffffff,
                              nullptr,
                              nullptr,
                              st->layerId,
                              0);
            }
        }

        // --- Retire / auto-lapse ---------------------------------------------
        if (st->phase - 2u < 2u) { // phase 2 or 3: resolved, playing its display
            if (m_toneJudgeFrames[st->phase] <= nFrameNo) {
                nm.setLaneFlag(st->noteId); // mark the pool lane fired
                st->noteId = 0xffffffffu;   // free the judge slot
            }
        } else if (st->phase == 1 && (noteFlags & kFlagInactive) != 0) {
            // A phase-1 note whose lane went inactive is auto-missed, its release
            // timestamp pushed out so the miss animation still plays out.
            st->phase = 2;
            st->result = 0;
            if (note.renderKind == NOTE_RENDER_SPECIAL) {
                const int graphic = NoteToneDefaultGraphic(note.kind);
                st->timestamp =
                    static_cast<int>(note.startTick) + specialLapseOffset(graphic, holdJudge);
            } else {
                st->timestamp = static_cast<int>(note.startTick) + 0x118;
            }
        }
    }

    // Combo-milestone bursts (Ghidra: DAT_00179000 = combo). Restart the burst
    // layer once at 25, 50, then every 50 beyond 100, edge-detected against the
    // previous frame's combo held in the play data (+0x9c2). That field is NOT a
    // monotonic "highest milestone" — the tail re-stamps it to the current combo
    // every frame (LAB_0002fe62), so after a combo reset the same milestone can
    // fire again on the way back up. Firing a milestone means restarting its
    // burst layer (Ghidra: AepLyrCtrl::Stop(layer, true) = stop(1), the replay-
    // from-head restart) and recording the crossed value in the HUD field
    // (+0x9c4). The if/else chain (only) is gated by the effect-enable check.
    const int combo = nm.combo();
    const short prevCombo = m_comboMilestoneGuard; // +0x9c2: last frame's combo
    if (comboBurstEnabled(this)) {
        if (prevCombo < 25 && combo > 24) {
            m_comboLayers[0]->stop(1);
            m_comboMilestoneShown = 25;
        } else if (prevCombo < 50 && combo > 49) {
            m_comboLayers[1]->stop(1);
            m_comboMilestoneShown = 50;
        } else if (combo > 99) {
            const int step = (combo / 50) * 50; // nearest 50 at or below the combo
            if (prevCombo < step && step <= combo) {
                m_comboLayers[2]->stop(1);
                m_comboMilestoneShown = static_cast<int16_t>(step);
            }
        }
    }

    // Sustained combo effect: while none of the burst layers are playing and the
    // combo is past 4, hold the sustain tier matching the combo band (5..9 ->
    // sceneLayers[0], 10..99 -> [1], 100+ -> [2]) paused at its frame and reset
    // the others; otherwise reset all three. Ghidra: the IsPlaying gate + the
    // Pause/Reset cascade at LAB_0002fe52/62.
    const bool burstIdle = !m_comboLayers[0]->isAnimating() && !m_comboLayers[1]->isAnimating() &&
                           !m_comboLayers[2]->isAnimating();
    if (burstIdle && combo > 4) {
        if (combo < 10) {
            m_sceneLayers[kSceneComboTier5]->pause();
            m_sceneLayers[kSceneComboTier10]->reset();
            m_sceneLayers[kSceneComboTier100]->reset();
        } else if (combo < 100) {
            m_sceneLayers[kSceneComboTier5]->reset();
            m_sceneLayers[kSceneComboTier10]->pause();
            m_sceneLayers[kSceneComboTier100]->reset();
        } else {
            m_sceneLayers[kSceneComboTier5]->reset();
            m_sceneLayers[kSceneComboTier10]->reset();
            m_sceneLayers[kSceneComboTier100]->pause();
        }
    } else {
        m_sceneLayers[kSceneComboTier5]->reset();
        m_sceneLayers[kSceneComboTier10]->reset();
        m_sceneLayers[kSceneComboTier100]->reset();
    }

    // Re-stamp +0x9c2 with the current combo every frame, regardless of the gate.
    m_comboMilestoneGuard = static_cast<short>(combo);

    // If any note resolved this frame, play the per-tap feedback SE.
    if (judgedAny || holdEnded) {
        playTouchSound(); // Ghidra: FUN_00031338 (per-tap feedback SE)
    }
}

// Ghidra: FUN_0003122c. The note engine's miss callback, registered at chart load
// and fired by detectMiss when a note scrolls past un-tapped. It is exactly the
// BAD/miss branch of the gauge update (raise the missed flag, subtract
// gaugeLossMiss, clamp [0, 0x400]), so it drains the life gauge on a miss just as
// a tapped BAD does.
void PlayApplyMissGauge(void *playData) {
    // playData is the PlayTask* registered as the miss-callback userdata
    // (PlayTask::start -> initPlayDataWithData(..., this)); the binary uses it
    // straight as the PlayTask base (@0x3122c: gauge fields at r0+0x9c0/0x9d4,
    // missed flag at r0+0x9dc), so recover it with a plain void* conversion.
    updateGaugeValue(static_cast<PlayTask *>(playData), NOTE_JUDGE_BAD);
}
