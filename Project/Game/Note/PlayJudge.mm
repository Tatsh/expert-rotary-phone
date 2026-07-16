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

#import <Foundation/Foundation.h>

#import "AepFrameDraw.h"
#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "NoteMng.h"
#import "PlayJudge.h"
#import "neGraphics.h"

#include <cmath> // lroundf, fmod (note frame), atan2/cos/sin (long-note bar angle)

// --- Play-data field access -------------------------------------------------
// The play data is the standard-mode MainTask; the note engine reaches it
// through the partial MainTaskPlayData overlay (PlayJudge.h), so field
// reads/writes below are plain named-member access at their binary-exact
// offsets.
namespace {

// The combo-milestone burst layers only restart while the play is live and the
// hit-effect option is on (Ghidra: the milestone if/else chain is wrapped in
// playData+0x9c9==0 && +0x9e5!=0 && +0x9e7==0 && +0x9ca==0).
inline bool comboBurstEnabled(const MainTaskPlayData *p) {
    return p->isDemoPlay == 0 && p->optEffectOn != 0 && p->optOldHardware == 0 &&
           p->isPadDisplay == 0;
}

constexpr int kJudgeStateCount = 60; // Ghidra: FUN_0003126c loop bound 0x3c

// Note flag bits (Ghidra: the (flags & mask) tests in the per-note body).
constexpr uint16_t kFlagJudged = 0xc0;    // already resolved -> skip
constexpr uint16_t kFlagInactive = 0x20;  // not yet on the judge field
constexpr uint16_t kFlagHold = 0x300;     // long-note span bits
constexpr uint16_t kFlagHoldOK = 0x100;   // hold completed
constexpr uint16_t kFlagHoldFail = 0x200; // hold broken

// Combo-milestone tracking global (Ghidra: DAT_00179000). The current combo the
// milestone jingles react to.
// (Read through NoteMng below; kept here for the milestone thresholds.)

// Ghidra: FUN_0003126c — find the judge state for pool note `noteId`, or claim a
// free slot and initialise it. Returns nullptr if the pool is full.
// @complete
NoteJudgeState *judgeStateFor(MainTaskPlayData *playData, unsigned noteId) {
    NoteJudgeState *pool = playData->judgePool; // the +0x3c8 pool
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
        if (freeSlot == nullptr && (int32_t)s->noteId < 0) {
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
// @complete
void updateGaugeValue(MainTaskPlayData *playData, int result) {
    int gauge = playData->gaugeValue;
    if (result == 2 || result == 3) {
        gauge = (int)lroundf((float)gauge + playData->gaugeGainGreat);
    } else if (result == 0) {
        playData->gaugeMissed = 1;
        gauge = (int)lroundf((float)gauge + playData->gaugeLossMiss);
    } else if (result == 1) {
        gauge = (int)lroundf((float)gauge + playData->gaugeGainGood);
    }
    if (gauge < 1) {
        gauge = 0;
    }
    if (gauge > 0x400) {
        gauge = 0x400;
    }
    playData->gaugeValue = (int16_t)gauge;
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
    const int8_t d = (int8_t)(graphic - (int)holdJudge);
    return d <= 0 ? 0x118 : (int)d * 0x118 + 0x118;
}

} // namespace

// Ghidra: FUN_0002f1f8.
// @complete
void PlayJudge_update(MainTaskPlayData *playData,
                      const float *touchXY,
                      const int *touchIds,
                      int touchCount) {
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
        xy[i] = touchXY != nullptr ? touchXY[i] : -1.0f;
    }

    const float beat = NoteBeatIntervalMs(); // Ghidra: GetBeatInterval (extraout_r0)
    const int curTime = nm.getCurrentPosition();
    const int noteCount = nm.getActiveNoteCount();
    const float scale = playData->playScale;
    const float radius = playData->hitRadius;
    const bool autoJudge = g_autoPlay;          // Ghidra: DAT_00187b59
    const bool stopping = playData->state == 5; // Ghidra: playData+0x9fc == 5

    bool judgedAny = false; // Ghidra bVar4: a tap/auto hit graded positive this frame
    bool holdEnded = false; // Ghidra bVar5: a long note completed this frame
    int boundCount = 0;     // Ghidra nBoundCount: fingers bound in non-spatial mode

    // Walk active notes nearest-the-judge-line last (high index -> low), so one
    // tap resolves the closest matching note.
    for (int index = noteCount - 1; index >= 0; --index) {
        NoteRenderData note;
        nm.getNoteObject(&note, index);
        if ((note.flags & kFlagJudged) != 0) {
            continue; // already fired / not judgeable
        }

        NoteJudgeState *st = judgeStateFor(playData, note.noteId);
        if (st == nullptr) {
            NSLog(@"PlayJudge: judge-state pool exhausted");
            continue;
        }

        // Seed the animation timestamp to the beat boundary at or before now,
        // counting back from the note's own time (drives the approach animation).
        if (st->timestamp == 0) {
            float t = (float)note.startTick;
            do {
                t -= beat;
            } while ((float)curTime < t);
            st->timestamp = (int)lroundf(t);
        }

        unsigned holdJudge = note.spawnKind; // Ghidra dwHoldJudge: hold-tap count

        // Approach -> active: once the note is within one beat of the judge line,
        // enter phase 1 and re-anchor the animation one beat before the note time.
        if (st->phase == 0 && (float)(int)(note.startTick - (unsigned)curTime) <= beat) {
            st->phase = 1;
            st->timestamp = (int)lroundf((float)note.startTick - beat);
        }

        const bool onField = (note.flags & kFlagInactive) == 0;

        // --- Judge / hit-test -------------------------------------------------
        // Judge this note if it is on the field and still open: either unresolved
        // (a fresh tap) or a SPECIAL note (renderKind 1) with taps remaining (a
        // re-tap that feeds judgeHold).
        if (onField && (st->result < 0 ||
                        (note.renderKind == NOTE_RENDER_SPECIAL && (int8_t)note.spawnKind > 0))) {
            if (!autoJudge) {
                if (touchCount > 0) {
                    if (playData->spatialTouchMode == 0) {
                        // Distance-test each live touch against the judge-line target.
                        for (int t = 0; t < touchCount; ++t) {
                            const float tx = xy[t * 2];
                            const float ty = xy[t * 2 + 1];
                            if (tx < 0.0f || ty < 0.0f) {
                                continue; // consumed / empty
                            }
                            const float dx = note.targetX - tx / scale;
                            const float dy = note.targetY - ty / scale;
                            if (dx * dx + dy * dy < radius * radius) {
                                if (st->result < 0) {
                                    st->result = nm.judgeNoteHit(note.noteId);
                                } else {
                                    holdJudge =
                                        (unsigned)nm.judgeHold(note.noteId, (unsigned)st->result);
                                }
                                judgedAny = judgedAny || st->result > 0;
                                if (st->result >= 0) {
                                    xy[t * 2] = -1.0f; // consume the touch
                                    xy[t * 2 + 1] = -1.0f;
                                    ++boundCount;
                                    if (touchIds != nullptr) {
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
                            holdJudge = (unsigned)nm.judgeHold(note.noteId, (unsigned)st->result);
                        }
                        judgedAny = judgedAny || st->result > 0;
                        if (st->result >= 0) {
                            if (touchIds != nullptr) {
                                st->touchId = touchIds[boundCount];
                            }
                            ++boundCount;
                        }
                    }
                }
            } else if ((note.flags & 0x2f) != 0) {
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
            (note.flags & 0x2f) != 0 && (note.flags & kFlagHold) == 0) {
            const bool fingerUp = st->touchId == -1 || gfx.findTouchById(st->touchId) == nullptr;
            if (fingerUp) {
                const unsigned r = (unsigned)nm.updateLongNote(note.noteId);
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
                if (note.endTick <= (unsigned)curTime && (noteFlags & kFlagHold) != 0) {
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
                updateGaugeValue(playData, st->result);
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
        int nFrameNo = (int)((float)(curTime - st->timestamp) / kFrameStepMs);
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
            const int last = playData->toneJudgeFrames[1] - 1;
            noteFrame = (int)((float)((curTime - st->timestamp) * last) / beat);
            if (noteFrame > last) {
                noteFrame = last;
            }
        } else if (st->phase == 0) {
            const int anchor = (int)((float)note.startTick - 0.5f * beat) - curTime;
            const int halfBeats = (int)((float)(unsigned)anchor / beat);
            if (halfBeats & 1) {
                const float ph = std::fmod(0.5f * beat + (float)(curTime - st->timestamp), beat);
                noteFrame = (int)(ph * (float)(playData->toneJudgeFrames[0] - 1) / beat);
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
        if (noteFrame < playData->toneJudgeFrames[st->phase]) {
            const float progress = (1024.0f - note.scrollStart) / 1024.0f;
            const int noteLayer = playData->toneJudgeLyr[st->phase]; // +0xc4[phase]
            const int drawScale = playData->noteDrawScale;           // +0x9bc
            for (int pt = 0; pt < 2; ++pt) {
                const float nx = (pt == 0) ? note.x : note.x2;
                const float ny = (pt == 0) ? note.y : note.y2;
                const int screenX = (int)(nx + progress * (note.targetX - nx));
                const int screenY = (int)(ny + progress * (note.targetY - ny));
                // Arg values resolved from the caller's stack push (0x2f818) mapped
                // onto drawLayer via the callee's r7-relative reads (0xfd64): layer,
                // frame, integer x/y, scale on both axes, then the constant tuple
                // {0, 150, 150, 100, 0, 1, 0x20, -1} with the note's own layer id in
                // the draw-context slot.
                aep.drawLayer(noteLayer,
                              noteFrame,
                              screenX,
                              screenY,
                              drawScale,
                              drawScale,
                              0,
                              150,
                              100,
                              0,
                              1,
                              150,
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
                    int span = (int)note.endTick - curTime;
                    const int full = (int)note.endTick - (int)note.startTick;
                    if (full < span) {
                        span = full;
                    }
                    const float fade =
                        span < 1 ? 0.0f : (span > 2999 ? 1.0f : (float)span / 3000.0f);

                    const int dx = (int)(nx - note.targetX);
                    const int dy = (int)(ny - note.targetY);
                    const double angleRad = (dx == 0) ? (dy < 0 ? -M_PI_2 : M_PI_2) :
                                                        std::atan2((double)dy, (double)dx);
                    const int angleDeg = (int)(angleRad * 180.0 / M_PI);
                    const float len =
                        fade * (float)playData->barLenScale + (float)playData->barLenBase;
                    const int prio = playData->barPriority / 2;

                    if (fade > 0.0f) {
                        const int bx = screenX + (int)(len * (float)std::cos(angleRad));
                        const int by = screenY + (int)(len * (float)std::sin(angleRad));
                        drawAepFrameEx(&aep,
                                       playData->barSegLyr0,
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
                    // The second segment sits at the note, scaled by fade*len.
                    const int seg2Scale = (int)(fade * len);
                    drawAepFrameEx(&aep,
                                   playData->barSegLyr1,
                                   screenX,
                                   screenY,
                                   seg2Scale,
                                   seg2Scale,
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

                // CD-jacket overlay at the note head (pt 0) when enabled and the
                // note is on the field but not yet spanning its hold: layer
                // effectStateLyr[12] (+0x114), frame cdFrame (+0x3c4), at the note's
                // interp position. Args traced at 0x2fa8c (blend 0x200, context 16).
                if (pt == 0 && playData->optJacket != 0 && (noteFlags & 0x2f) != 0 &&
                    (noteFlags & kFlagHold) == 0) {
                    const int effScale = playData->hitEffectScale / 2;
                    aep.drawLayer(playData->effectStateLyr[12],
                                  playData->cdFrame,
                                  screenX,
                                  screenY,
                                  drawScale,
                                  drawScale,
                                  0,
                                  effScale,
                                  100,
                                  0,
                                  1,
                                  effScale,
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
        const int hx = (int)note.targetX;
        const int hy = (int)note.targetY;
        const int effScale = playData->hitEffectScale / 2; // +0x9e0

        if (st->phase == 1 && noteFrame < playData->effectStateFrames[1]) {
            aep.drawLayer(playData->effectStateLyr[1],
                          noteFrame,
                          hx,
                          hy,
                          100,
                          100,
                          0,
                          effScale,
                          100,
                          0,
                          1,
                          effScale,
                          0x20,
                          0xffffffff,
                          nullptr,
                          nullptr,
                          20,
                          0);
        }

        if (st->result >= 0) {
            const int hitScale = playData->noteDrawScale; // +0x9bc
            // Whether the GOOD/GREAT/COOL burst shows for this render kind (0x2fb84):
            // a SPECIAL note only once its hold-tap count is exhausted, a LONG note
            // only with its hold-completed bit set.
            const bool showBurst =
                note.renderKind == NOTE_RENDER_NORMAL ||
                (note.renderKind == NOTE_RENDER_SPECIAL && (holdJudge & 0xff) == 0) ||
                (note.renderKind == NOTE_RENDER_LONG && (noteFlags & kFlagHoldOK) != 0);
            if (showBurst && st->result >= 1 && st->result <= 3 &&
                nFrameNo < playData->effectStateFrames[st->result + 1]) {
                aep.drawLayer(playData->effectStateLyr[st->result + 1],
                              nFrameNo,
                              hx,
                              hy,
                              hitScale,
                              hitScale,
                              0,
                              effScale,
                              100,
                              0,
                              1,
                              effScale,
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
            if (showBase && nFrameNo < playData->effectStateFrames[0]) {
                aep.drawLayer(playData->effectStateLyr[0],
                              nFrameNo,
                              hx,
                              hy,
                              hitScale,
                              hitScale,
                              0,
                              0,
                              100,
                              0,
                              1,
                              0,
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
            if (playData->toneJudgeFrames[st->phase] <= nFrameNo) {
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
                st->timestamp = (int)note.startTick + specialLapseOffset(graphic, holdJudge);
            } else {
                st->timestamp = (int)note.startTick + 0x118;
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
    const short prevCombo = playData->lastMilestone; // +0x9c2: last frame's combo
    if (comboBurstEnabled(playData)) {
        if (prevCombo < 25 && combo > 24) {
            playData->comboLayers[0]->stop(1);
            playData->comboMilestoneShown = 25;
        } else if (prevCombo < 50 && combo > 49) {
            playData->comboLayers[1]->stop(1);
            playData->comboMilestoneShown = 50;
        } else if (combo > 99) {
            const int step = (combo / 50) * 50; // nearest 50 at or below the combo
            if (prevCombo < step && step <= combo) {
                playData->comboLayers[2]->stop(1);
                playData->comboMilestoneShown = (int16_t)step;
            }
        }
    }

    // Sustained combo effect: while none of the burst layers are playing and the
    // combo is past 4, hold the sustain tier matching the combo band (5..9 ->
    // sceneLayers[0], 10..99 -> [1], 100+ -> [2]) paused at its frame and reset
    // the others; otherwise reset all three. Ghidra: the IsPlaying gate + the
    // Pause/Reset cascade at LAB_0002fe52/62.
    const bool burstIdle = !playData->comboLayers[0]->isAnimating() &&
                           !playData->comboLayers[1]->isAnimating() &&
                           !playData->comboLayers[2]->isAnimating();
    if (burstIdle && combo > 4) {
        if (combo < 10) {
            playData->sceneLayers[0]->pause();
            playData->sceneLayers[1]->reset();
            playData->sceneLayers[2]->reset();
        } else if (combo < 100) {
            playData->sceneLayers[0]->reset();
            playData->sceneLayers[1]->pause();
            playData->sceneLayers[2]->reset();
        } else {
            playData->sceneLayers[0]->reset();
            playData->sceneLayers[1]->reset();
            playData->sceneLayers[2]->pause();
        }
    } else {
        playData->sceneLayers[0]->reset();
        playData->sceneLayers[1]->reset();
        playData->sceneLayers[2]->reset();
    }

    // Re-stamp +0x9c2 with the current combo every frame, regardless of the gate.
    playData->lastMilestone = (short)combo;

    // If any note resolved this frame, play the per-tap feedback SE.
    if (judgedAny || holdEnded) {
        PlayScoreGaugeUpdate(playData); // Ghidra: FUN_00031338 (per-tap feedback SE)
    }
}

// Ghidra: FUN_0003122c. The note engine's miss callback, registered at chart load
// and fired by detectMiss when a note scrolls past un-tapped. It is exactly the
// BAD/miss branch of the gauge update (raise the missed flag, subtract
// gaugeLossMiss, clamp [0, 0x400]), so it drains the life gauge on a miss just as
// a tapped BAD does.
// @complete
void PlayApplyMissGauge(void *playData) {
    updateGaugeValue(reinterpret_cast<MainTaskPlayData *>(playData), NOTE_JUDGE_BAD);
}
