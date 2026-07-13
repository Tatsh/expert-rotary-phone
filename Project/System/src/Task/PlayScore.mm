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
//    - PlayScoreGaugeUpdate Ghidra: FUN_00031338
//        Called after any frame that resolved a note (PlayJudge_update's tail).
//        Its name is historical: the running score itself is recomputed by the
//        state-6 caller via PlayCurrentScore; this routine only (re)fires the
//        per-judge gauge feedback SE, retriggering the loaded source (+0x398)
//        and dropping the prior instance (+0x3a0), gated by the gauge-enable
//        count (+0x9b4) and skipped while the pause menu (state 5) is up.
//        Verified against the disassembly, not the heavier score math the name
//        suggests.
//
//    - PlayEndResultSe      Ghidra: the rank-SE cascade in PlayTask_update
//        (FUN_0002dc14) state 6, ~0x2e0d0..0x2e190. Chooses one of several
//        pre-created SE-instance jingles from the final score + combo/tally,
//        plus a clear fanfare.
//
//  The play data is the standard-mode MainTask (PlayJudge.h's forward-declared
//  MainTaskPlayData); the fields these routines touch are reached by cited byte
//  offset in the pd()/pdw() style PlayJudge.mm established.
//

#import <Foundation/Foundation.h>

#import "AudioManager.h"
#import "NoteMng.h"
#import "PlayJudge.h"  // MainTaskPlayData (fwd), PlayScoreGaugeUpdate proto
#import "PlayTask.h"   // PlayCurrentScore / PlayEndResultSe protos
#import "SeInstance.h" // SeInstanceIsBusy / SeInstancePlay / SeInstancePlayMode

// --- Play-data field access -------------------------------------------------
// Same convention as PlayJudge.mm: the standard-mode MainTask is not
// reconstructed as a whole, so its fields are reached by documented byte
// offset.
namespace {

inline const char *pd(const void *p) {
    return reinterpret_cast<const char *>(p);
}
inline char *pdw(void *p) {
    return reinterpret_cast<char *>(p);
}

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

// The per-play SE-instance handles the play data pre-creates. Each is a pointer
// to an SeInstance controller (see SeInstance.h), owned by the scene. Ghidra:
// the play task fires *(playData + off) as an SE-instance through
// FUN_0002cba4/cac0/cb24.
inline void *seHandle(void *playData, int off) {
    return *reinterpret_cast<void *const *>(pd(playData) + off);
}

// Song-clear rank jingle handle offsets (Ghidra: PlayTask_update state 6).
constexpr int kSeClearMiss = 0xa8;    // score>=70000, some GOOD/BAD, combo broken
constexpr int kSeClearFC = 0xac;      // score>=70000, some GOOD/BAD, full combo
constexpr int kSePerfectGreat = 0xb0; // score>=70000, no GOOD/BAD, at least one GREAT
constexpr int kSePerfectCool = 0xb4;  // score>=70000, no GOOD/BAD, all COOL
constexpr int kSeFailMiss = 0xb8;     // score<70000, combo broken
constexpr int kSeFailFC = 0xbc;       // score<70000, full combo
constexpr int kSeClearFanfare = 0xc0; // score>=70000, always (over the rank jingle)

// PlayScoreGaugeUpdate play-data fields (Ghidra: FUN_00031338 disassembly).
// +0x9b4 is the user's touch-sound volume (PlayTask_init reads it from
// UserSettingData::touchSoundVolume); a zero volume mutes the per-tap SE.
constexpr int kTouchSoundVolume = 0x9b4; // short: tap-sound volume; SE gated on > 0
constexpr int kTouchSeSource = 0x398;    // RSND_SOURCE_ID of the loaded tap-feedback SE
constexpr int kTouchSeInstance = 0x3a0;  // int: currently playing instance id (-1 = none)
constexpr int kTaskState = 0x9fc;        // int: play state machine (5 = pause menu)

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

// Fire an SE-instance jingle if its controller is idle. Ghidra: the repeated
// `if (FUN_0002cba4(handle) == 0) FUN_0002cac0(handle);` idiom.
inline void firePlay(void *playData, int off) {
    void *inst = seHandle(playData, off);
    if (!SeInstanceIsBusy(inst)) {
        SeInstancePlay(inst);
    }
}

} // namespace

// Ghidra: FUN_0002ff7c.
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
void PlayScoreGaugeUpdate(MainTaskPlayData *playData) {
    // Play the per-tap feedback SE only when the user's touch-sound volume is on,
    // and never while the pause menu is up (state 5).
    if (*reinterpret_cast<const short *>(pd(playData) + kTouchSoundVolume) <= 0) {
        return;
    }
    if (*reinterpret_cast<const int *>(pd(playData) + kTaskState) == 5) {
        return;
    }

    AudioManager *audio = [AudioManager sharedManager];

    // Drop any still-playing tap instance before retriggering.
    int *instanceField = reinterpret_cast<int *>(pdw(playData) + kTouchSeInstance);
    if (*instanceField != -1) {
        [audio stopSe:static_cast<RSND_INSTANCE_ID>(*instanceField)];
        *instanceField = -1;
    }

    const RSND_SOURCE_ID source =
        *reinterpret_cast<const RSND_SOURCE_ID *>(pd(playData) + kTouchSeSource);
    *instanceField = static_cast<int>([audio playSe:nil resourceId:source]);
}

// Ghidra: the SE-instance rank cascade in PlayTask_update (FUN_0002dc14) state
// 6, ~0x2e0d0..0x2e190. `score` is the value PlayCurrentScore produced (play
// data +0x9b0).
void PlayEndResultSe(void *playData, int score) {
    NoteMng &nm = NoteMng::shared();
    const TallyTotals t = collectTally(nm);
    const int noteTotal = nm.totalNoteCount(); // Ghidra: DAT_00178ccc

    // Full combo when the combo reached the note total (Ghidra: the branches test
    // "DAT_00179000 < DAT_00178ccc", i.e. combo < total, for a broken combo).
    const bool fullCombo = nm.combo() >= noteTotal;

    if (score < kClearScore) {
        // Below the clear line: the "not cleared" jingle, full-combo variant if
        // unbroken.
        firePlay(playData, fullCombo ? kSeFailFC : kSeFailMiss);
        return;
    }

    // Cleared. The top-rank jingles require a spotless sheet: no GOOD or BAD,
    // i.e. COOL + GREAT covers every note (Ghidra: FUN_00031868 predicate, the
    // summed COOL + GREAT tally columns >= the note-total threshold).
    const bool spotless = (t.cool + t.great) >= noteTotal;
    if (spotless) {
        // All COOL -> the perfect jingle; any GREAT -> the full-perfect jingle.
        firePlay(playData, (t.great == 0) ? kSePerfectCool : kSePerfectGreat);
    } else {
        // Cleared with some GOOD/BAD: full-combo or broken-combo clear jingle.
        firePlay(playData, fullCombo ? kSeClearFC : kSeClearMiss);
    }

    // A clear always layers the clear fanfare over the chosen rank jingle
    // (Ghidra: FUN_0002cb24(*(playData + 0xc0), 1) after the rank pick).
    void *fanfare = seHandle(playData, kSeClearFanfare);
    if (!SeInstanceIsBusy(fanfare)) {
        SeInstancePlayMode(fanfare, 1);
    }
}
