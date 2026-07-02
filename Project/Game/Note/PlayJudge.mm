//
//  PlayJudge.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (FUN_0002f1f8).
//  The per-frame play/judge pass of the standard-mode main task.
//
//  This carries the verified judge control flow: for each still-judgeable active
//  note it looks up (or allocates) the note's judge state, hit-tests the current
//  touches against the note's judge-line target, dispatches taps to
//  NoteMng::judgeNoteHit (or auto-judges in demo mode), tracks holds by the bound
//  finger via neGraphics, drives the visual phase state machine, draws the note +
//  its hit effect, and fires the combo-milestone jingles.
//
//  Two areas are delegated rather than re-derived from the original's NEON/16.16
//  fixed-point math, to avoid inventing pixel geometry: the note quad / hit-effect
//  draw (Ghidra FUN_0000fd64 / FUN_0000fcd0 — the note-sprite draw unit) and the
//  SE-voice instance bookkeeping at the tail (FUN_0002cb24/54/5c/64). Both are
//  their own reconstruction units; see HANDOFF.md.
//

#import <Foundation/Foundation.h>

#import "NoteMng.h"
#import "PlayJudge.h"
#import "neGraphics.h"

// --- Play-data field access -------------------------------------------------
// The play data is the standard-mode MainTask (not yet reconstructed as a whole).
// The fields this pass reads are cited by byte offset here.
namespace {

inline const char *pd(const MainTaskPlayData *p) { return reinterpret_cast<const char *>(p); }
inline char *pdw(MainTaskPlayData *p) { return reinterpret_cast<char *>(p); }

inline float playScale(const MainTaskPlayData *p)   { return *reinterpret_cast<const float *>(pd(p) + 0x974); }
inline float hitRadius(const MainTaskPlayData *p)    { return *reinterpret_cast<const float *>(pd(p) + 0x9b8); }
inline bool  isSpatialTouch(const MainTaskPlayData *p) { return pd(p)[0x9e4] == 0; }   // 0 = distance test
inline int   taskState(const MainTaskPlayData *p)    { return *reinterpret_cast<const int *>(pd(p) + 0x9fc); }

// The three combo-milestone SE-instance handles the play data pre-creates:
// +0x84 fires at 25 combo, +0x88 at 50, +0x8c at every 50 past 100. Each is a
// pointer to an SE-instance/effect object owned elsewhere (Ghidra: the
// FUN_0002cb24(*(playData+0x84/0x88/0x8c), 1) calls in the milestone tail).
inline void *milestoneSe(const MainTaskPlayData *p, int off) {
    return *reinterpret_cast<void *const *>(pd(p) + off);
}

// Milestone SEs only fire while the play is live (Ghidra: the milestone tail is
// wrapped in pd[0x9c9]==0 && pd[0x9e5]!=0 && pd[0x9e7]==0 && pd[0x9ca]==0).
inline bool milestoneSeEnabled(const MainTaskPlayData *p) {
    return pd(p)[0x9c9] == 0 && pd(p)[0x9e5] != 0 &&
           pd(p)[0x9e7] == 0 && pd(p)[0x9ca] == 0;
}

// Issue the SE-instance "play" command (Ghidra: FUN_0002cb24 with mode 1). The
// object's command byte (+0x58) is set to 3 (play) and its frame cursor (+0x40,
// a float) is rewound to the head, or to the last frame when the playback rate
// (+0x44) runs backwards; the per-frame SE-instance update consumes the command.
inline void seInstancePlay(void *inst) {
    char *o = reinterpret_cast<char *>(inst);
    *reinterpret_cast<int *>(o + 0x58) = 3;   // command = play
    if (*reinterpret_cast<const float *>(o + 0x44) <= 0.0f) {
        int frames = *reinterpret_cast<const int *>(o + 0x3c);
        *reinterpret_cast<float *>(o + 0x40) = static_cast<float>(frames - 1);
    } else {
        *reinterpret_cast<float *>(o + 0x40) = 0.0f;
    }
}

// The 60-entry judge-state pool lives at +0x3c8, each entry 24 bytes.
inline NoteJudgeState *judgeStatePool(MainTaskPlayData *p) {
    return reinterpret_cast<NoteJudgeState *>(pdw(p) + 0x3c8);
}
constexpr int kJudgeStateCount = 60;   // Ghidra: FUN_0003126c loop bound 0x3c

// Note flag bits (Ghidra: the (flags & mask) tests in the per-note body).
constexpr uint16_t kFlagJudged   = 0xc0;    // already resolved -> skip
constexpr uint16_t kFlagInactive = 0x20;    // not yet on the judge field
constexpr uint16_t kFlagHold     = 0x300;   // long-note span bits
constexpr uint16_t kFlagHoldOK   = 0x100;   // hold completed
constexpr uint16_t kFlagHoldFail = 0x200;   // hold broken

// Combo-milestone tracking global (Ghidra: DAT_00179000). The current combo the
// milestone jingles react to.
// (Read through NoteMng below; kept here for the milestone thresholds.)

// Ghidra: FUN_0003126c — find the judge state for `noteKey`, or claim a free slot
// (noteKey == nullptr) and initialise it. Returns nullptr if the pool is full.
NoteJudgeState *judgeStateFor(MainTaskPlayData *playData, const void *noteKey) {
    NoteJudgeState *pool = judgeStatePool(playData);
    NoteJudgeState *freeSlot = nullptr;
    for (int i = 0; i < kJudgeStateCount; ++i) {
        NoteJudgeState *s = &pool[i];
        if (s->noteKey == noteKey) {
            return s;
        }
        if (freeSlot == nullptr && s->noteKey == nullptr) {
            freeSlot = s;
        }
    }
    if (freeSlot != nullptr) {
        freeSlot->noteKey = noteKey;
        freeSlot->phase = 0;
        freeSlot->result = -1;
        freeSlot->timestamp = 0;
        freeSlot->touchId = -1;
        return freeSlot;
    }
    return nullptr;
}

// Whether the play is in demo/auto-judge mode (Ghidra: DAT_00187b59).
bool g_autoPlay = false;   // extern flag in the binary; false in normal play

}  // namespace

// The global combo counter the milestone jingles read (Ghidra: DAT_00179000).
static int g_combo = 0;

// Ghidra: FUN_0002f1f8.
void PlayJudge_update(MainTaskPlayData *playData, const float *touchXY,
                      const int *touchIds, int touchCount) {
    NoteMng &nm = NoteMng::shared();
    neGraphics &gfx = neGraphics::shared();

    // Snapshot the touch points; a negative coordinate marks an empty/consumed
    // slot. The original copies a fixed 0x40-byte (8 x,y pairs) block.
    constexpr int kMaxTouches = 8;
    float xy[kMaxTouches * 2];
    for (int i = 0; i < kMaxTouches * 2; ++i) {
        xy[i] = (touchXY != nullptr && i < touchCount * 2) ? touchXY[i] : -1.0f;
    }

    const int currentPos = nm.getCurrentPosition();
    const int noteCount = nm.getActiveNoteCount();
    const float scale = playScale(playData);
    const float radius = hitRadius(playData);
    const bool stopping = taskState(playData) == 5;

    bool judgedAny = false;   // Ghidra bVar2: a tap/auto hit fired this frame
    bool holdEnded = false;   // Ghidra bVar3: a hold resolved this frame

    // Walk active notes nearest-the-judge-line last (high index -> low), so one
    // tap resolves the closest matching note.
    for (int index = noteCount - 1; index >= 0; --index) {
        NoteRenderData note;
        nm.getNoteObject(&note, index);
        if ((note.flags & kFlagJudged) != 0) {
            continue;   // already judged / not judgeable
        }

        NoteJudgeState *state = judgeStateFor(playData, note.rec);
        if (state == nullptr) {
            NSLog(@"PlayJudge: judge-state pool exhausted");
            continue;
        }

        // Judge this note if it is on the field and still unresolved.
        const bool onField = (note.flags & kFlagInactive) == 0;
        if (onField && (state->result < 0 || (note.kind == 1 && note.spawnKind > 0))) {
            if (!g_autoPlay) {
                if (isSpatialTouch(playData)) {
                    // Distance test each live touch against the judge-line target.
                    for (int t = 0; t < touchCount; ++t) {
                        float tx = xy[t * 2];
                        float ty = xy[t * 2 + 1];
                        if (tx < 0.0f || ty < 0.0f) {
                            continue;   // consumed / empty
                        }
                        const float dx = note.targetX - tx / scale;
                        const float dy = note.targetY - ty / scale;
                        if (dx * dx + dy * dy < radius * radius) {
                            if (state->result < 0) {
                                state->result = nm.judgeNoteHit((unsigned)index);
                            }
                            judgedAny = judgedAny || state->result > 0;
                            if (state->result >= 0) {
                                xy[t * 2] = -1.0f;   // consume the touch
                                xy[t * 2 + 1] = -1.0f;
                                if (touchIds != nullptr) {
                                    state->touchId = touchIds[t];   // bind the finger
                                }
                                break;
                            }
                        }
                    }
                } else if (state->result < 0) {
                    // Non-spatial mode: consume touches in order.
                    state->result = nm.judgeNoteHit((unsigned)index);
                    judgedAny = judgedAny || state->result > 0;
                    if (state->result >= 0 && touchIds != nullptr && touchCount > 0) {
                        state->touchId = touchIds[0];
                    }
                }
            } else if ((note.flags & 0x2f) != 0) {
                state->result = 3;   // demo mode auto-judges
                judgedAny = true;
            }
        }

        // Hold resolution: while not stopping and this is an unfinished hold, keep
        // it alive as long as the bound finger is still down; otherwise advance it.
        if (!stopping && onField && (note.flags & kFlagHold) == 0) {
            bool fingerDown = state->touchId != -1 && gfx.findTouchById(state->touchId) != nullptr;
            if (!fingerDown) {
                int holdFlags = nm.updateLongNote((unsigned)index);
                if (holdFlags & kFlagHoldFail) {
                    state->phase = 2;
                    state->result = 0;
                    state->timestamp = currentPos;
                } else if (holdFlags & kFlagHoldOK) {
                    // Success tier from the returned bits (Ghidra: 4 -> 3, 2 -> 2, else 1).
                    state->result = (holdFlags & 4) ? 3 : (holdFlags & 2) ? 2 : 1;
                }
            }
        }

        // Visual phase state machine: a resolved note advances to a display phase
        // (2 = hit / 3 = miss) and records the position it changed at.
        if (state->result >= 0 && state->phase < 2) {
            state->phase = (state->result == 0) ? 2 : 3;
            state->timestamp = currentPos;
            if (state->result > 0) {
                holdEnded = true;
            }
        }

        // Draw the note quad + its hit effect at the current animation position.
        // (Ghidra FUN_0000fd64 / FUN_0000fcd0 — the note-sprite draw unit; the
        // 16.16/NEON geometry is reconstructed there, not here.)
    }

    // Combo-milestone jingles (Ghidra: DAT_00179000 = combo). Fire once at 25, 50,
    // then every 50 beyond 100, tracked by the last milestone in the play data
    // (+0x9c2) so a milestone is not re-triggered every frame. Each tier owns a
    // pre-created SE-instance handle in the play data and firing the jingle means
    // issuing that instance's "play" command (Ghidra: FUN_0002cb24(handle, 1) on
    // *(playData+0x84) at 25, *(playData+0x88) at 50, *(playData+0x8c) past 100).
    g_combo = nm.combo();
    short *lastMilestone = reinterpret_cast<short *>(pdw(playData) + 0x9c2);
    int milestone = 0;
    int seHandleOffset = 0;
    if (g_combo >= 25 && *lastMilestone < 25) {
        milestone = 25;
        seHandleOffset = 0x84;
    } else if (g_combo >= 50 && *lastMilestone < 50) {
        milestone = 50;
        seHandleOffset = 0x88;
    } else if (g_combo >= 100) {
        int step = (g_combo / 50) * 50;   // nearest 50 at or below the combo
        if (*lastMilestone < step) {
            milestone = step;
            seHandleOffset = 0x8c;
        }
    }
    if (milestone != 0) {
        // Fire the tier's jingle through its SE-instance handle, but only while
        // the play is live (Ghidra: the milestone tail's enable gate).
        if (milestoneSeEnabled(playData)) {
            seInstancePlay(milestoneSe(playData, seHandleOffset));
        }
        *lastMilestone = (short)milestone;
    }

    // If anything resolved this frame, play the per-tap feedback SE.
    if (judgedAny || holdEnded) {
        PlayScoreGaugeUpdate(playData);   // Ghidra: FUN_00031338 (per-tap feedback SE)
    }
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
