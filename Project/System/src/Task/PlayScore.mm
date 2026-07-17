//
//  PlayScore.mm
//  pop'n rhythmin
//
//  The standard-mode play scene's score / gauge-feedback / song-clear sound
//  logic, reconstructed from Ghidra project rb420, program PopnRhythmin. Three
//  seams the play task declares live here:
//
//    - PlayCurrentScore     Ghidra: FUN_0002ff7c
//        The running score: a weighted accuracy of the per-note-kind hit tally,
//        scaled to a 100000-point maximum. PlayTask_update state 6 stores its
//        result into the play data (+0x9b0) each frame and the results screen
//        reads it back.
//
//    - PlayTask::playTouchSound Ghidra: FUN_00031338
//        Called after any frame that resolved a note (playJudgeUpdate's tail).
//        It (re)fires the per-tap feedback SE, retriggering the loaded source
//        (+0x398) and dropping the prior instance (+0x3a0), gated by the
//        touch-sound volume (+0x9b4) and skipped while the pause menu (state 5)
//        is up. Verified against the disassembly.
//
//    - PlayTask::playEndResultSe Ghidra: the rank-SE cascade in PlayTask_update
//        (FUN_0002dc14) state 6, ~0x2e0d0..0x2e190. Chooses one of several
//        pre-created SE-cue jingle layers from the final score + combo/tally,
//        plus a clear fanfare.
//
//  The play data is the standard-mode play task, PlayTask; playTouchSound and
//  playEndResultSe are PlayTask methods reaching its named members directly (the
//  SE-cue jingles are m_sceneLayers[4..10], see the SceneLayer enum).
//

#import <Foundation/Foundation.h>

#import "AudioManager.h"
#import "NoteMng.h"
#import "PlayTask.h"
#import "SeInstance.h" // SeInstanceIsBusy / SeInstancePlay / SeInstancePlayMode

namespace {

// Score weights, byte-verified from the Ghidra float constants:
//   DAT_00030030 = 0x3f333333 = 0.7  (GREAT weight)
//   DAT_00030034 = 0x3ecccccd = 0.4  (GOOD  weight)
//   DAT_00030038 = 0x47c35000 = 100000.0 (perfect-score scale)
// COOL keeps the implicit 1.0 weight; BAD contributes nothing.
constexpr float kWeightGreat = 0.7f;
constexpr float kWeightGood = 0.4f;
constexpr float kScoreMax = 100000.0f;

// Below this the play "failed" rank jingles fire (Ghidra: score < 70000).
constexpr int kClearScore = 70000;

// One tally snapshot of the global note manager. The engine keeps a hit count
// per note kind (0..9) per judge tier (COOL/GREAT/GOOD/BAD). Ghidra: the three
// stride-0x10 accumulation loops over the tally columns at NoteMng +0x5170
// (COOL), +0x516c (GREAT) and +0x5168 (GOOD) in FUN_0002ff7c. The score's
// denominator is the fixed chart note total (DAT_00178ccc,
// NoteMng::totalNoteCount()), not this running sum. Only the three scored tiers
// are summed; BAD carries no weight and is not read by either FUN_0002ff7c or
// the FUN_00031868 predicate, matching the binary.
struct TallyTotals {
    int cool = 0;
    int great = 0;
    int good = 0;
};

TallyTotals collectTally(NoteMng &nm) {
    TallyTotals t;
    for (int kind = 0; kind < kNoteKindCount; ++kind) {
        t.cool += nm.judgeCount(kind, NOTE_JUDGE_COOL);
        t.great += nm.judgeCount(kind, NOTE_JUDGE_GREAT);
        t.good += nm.judgeCount(kind, NOTE_JUDGE_GOOD);
    }
    return t;
}

} // namespace

// Ghidra: FUN_0002ff7c.
// Verified against the disassembly at 0x2ff96..0x3002c: three stride-0x10
// accumulation loops sum the COOL (+0x5170), GREAT (+0x516c), and GOOD (+0x5168)
// tally columns; the note total is the sign-extended halfword at +0x4e28. The
// VFP tail computes (cool + great * 0.7 + good * 0.4) * 100000 / total and
// truncates it with vcvt.s32.f32 (COOL/GOOD converted unsigned, the total
// signed). The literal-pool words 0x3f333333, 0x3ecccccd, and 0x47c35000 give
// 0.7, 0.4, and 100000.0. The binary has no divisor guard; the noteTotal <= 0
// early return here is a disclosed defensive addition for the no-chart case, and
// the scored path is byte-faithful otherwise.
// @complete
int PlayCurrentScore() {
    NoteMng &nm = NoteMng::shared(); // Ghidra: NoteMng_shared() at entry
    const TallyTotals t = collectTally(nm);
    const int noteTotal = nm.totalNoteCount(); // Ghidra: DAT_00178ccc (fixed divisor)
    if (noteTotal <= 0) {
        // No chart loaded: the original's fixed-point path would divide by zero.
        return 0;
    }
    // score = (COOL*1.0 + GREAT*0.7 + GOOD*0.4) * 100000 / totalNotes,
    // accumulating toward the 100000-point maximum as notes are hit.
    const float weighted = static_cast<float>(t.cool) + static_cast<float>(t.great) * kWeightGreat +
                           static_cast<float>(t.good) * kWeightGood;
    return static_cast<int>(weighted * kScoreMax / static_cast<float>(noteTotal));
}

// Ghidra: FUN_00031338.
// Verified against the disassembly at 0x3133e..0x313aa: the guard is
// `ldrsh +0x9b4; cmp #1; blt` (return when the touch-sound volume is <= 0) then
// `ldr +0x9fc; cmp #5` (return on the pause-menu state); the still-playing
// instance at +0x3a0 is stopped and reset to -1 before the +0x398 source is
// retriggered and its new instance id stored back into +0x3a0.
// @complete
void PlayTask::playTouchSound() {
    // Play the per-tap feedback SE only when the user's touch-sound volume is on,
    // and never while the pause menu is up (state 5).
    if (m_seVolume <= 0) {
        return;
    }
    if (m_state == 5) {
        return;
    }

    AudioManager *audio = [AudioManager sharedManager];

    // Drop any still-playing tap instance before retriggering.
    int *instanceField = &m_timingSeInst[0];
    if (*instanceField != -1) {
        [audio stopSe:static_cast<RSND_INSTANCE_ID>(*instanceField)];
        *instanceField = -1;
    }

    // m_hitSeId is a 4-byte SE source id (RSND_SOURCE_ID is unsigned long, 8 bytes
    // on the 64-bit target, so the field stays int and widens implicitly here).
    *instanceField = static_cast<int>([audio playSe:nil resourceId:m_hitSeId]);
}

// Fire one m_sceneLayers cue layer (an AepLyrCtrl driven as an SE) if it is idle.
// Ghidra: the repeated `if (FUN_0002cba4(layer) == 0) FUN_0002cac0(layer);` idiom.
void PlayTask::firePlayCue(int layer) {
    AepLyrCtrl *inst = m_sceneLayers[layer];
    if (!SeInstanceIsBusy(inst)) {
        SeInstancePlay(inst);
    }
}

// Ghidra: the SE-instance rank cascade in PlayTask_update (FUN_0002dc14) state
// 6, ~0x2e0aa..0x2e17c. `score` is the value PlayCurrentScore produced (play
// data +0x9b0). Verified against the disassembly: the clear line is `cmp` with
// 0x11170 (70000); full combo is `cmp total(+0x4e28), combo(+0x515c); bls`;
// spotless is FUN_00031868 returning 1 when (COOL + GREAT) >= total. The fired
// layers match the binary's branches exactly — fail: [9] (full) / [8] (broken);
// cleared-with-good: [5] (full) / [4] (broken); spotless: [7] (all COOL) / [6]
// (any GREAT) — and every cleared path layers the [10] fanfare via
// FUN_0002cb24(layer, 1).
// @complete
void PlayTask::playEndResultSe(int score) {
    NoteMng &nm = NoteMng::shared();
    const TallyTotals t = collectTally(nm);
    const int noteTotal = nm.totalNoteCount(); // Ghidra: DAT_00178ccc

    // Full combo when the combo reached the note total (Ghidra: the branches test
    // "DAT_00179000 < DAT_00178ccc", i.e. combo < total, for a broken combo).
    const bool fullCombo = nm.combo() >= noteTotal;

    if (score < kClearScore) {
        // Below the clear line: the "not cleared" jingle, full-combo variant if
        // unbroken.
        firePlayCue(fullCombo ? kSceneRankFailFC : kSceneRankFailMiss);
        return;
    }

    // Cleared. The top-rank jingles require a spotless sheet: no GOOD or BAD,
    // i.e. COOL + GREAT covers every note (Ghidra: FUN_00031868 predicate, the
    // summed COOL + GREAT tally columns >= the note-total threshold).
    const bool spotless = (t.cool + t.great) >= noteTotal;
    if (spotless) {
        // All COOL -> the perfect jingle; any GREAT -> the full-perfect jingle.
        firePlayCue((t.great == 0) ? kSceneRankPerfectCool : kSceneRankPerfectGreat);
    } else {
        // Cleared with some GOOD/BAD: full-combo or broken-combo clear jingle.
        firePlayCue(fullCombo ? kSceneRankClearFC : kSceneRankClearMiss);
    }

    // A clear always layers the clear fanfare over the chosen rank jingle
    // (Ghidra: FUN_0002cb24(*(playData + 0xc0), 1) after the rank pick).
    AepLyrCtrl *fanfare = m_sceneLayers[kSceneRankFanfare];
    if (!SeInstanceIsBusy(fanfare)) {
        SeInstancePlayMode(fanfare, 1);
    }
}
