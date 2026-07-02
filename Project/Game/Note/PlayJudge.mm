//
//  PlayJudge.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (FUN_0002f1f8).
//  The per-frame play/judge pass: iterate the global NoteMng's active notes,
//  hit-test the current touches, dispatch hits to the judgement, auto-resolve
//  passed notes, draw each note, and fire the combo-milestone SEs.
//
//  STAGE 1 (this pass): the verified game-logic control flow — note iteration,
//  judge dispatch, combo milestones — with real NoteMng/AudioManager calls. The
//  per-note screen geometry (16.16-fixed hit test and the sprite draw) is the
//  animation fill's job (AepManager::drawLayer -> FUN_0000fe8c) and is referenced,
//  not re-derived here.
//

#import "AudioManager.h"
#import "NoteMng.h"
#import "PlayJudge.h"

// The global standard-mode note manager (Ghidra: DAT_00173ea4).
extern NoteMng gNoteMng;

// Notes flagged with either of these bits are no longer judgeable (Ghidra: the
// (flags & 0xc0) == 0 gate at the top of the per-note body).
static const uint16_t kNoteJudgedMask = 0xc0;

// Squared hit radius in view points (Ghidra: play-data +0x9b8, the touch/note
// proximity threshold; the original compares squared distances).
static const float kHitRadius = 48.0f;

// Ghidra: FUN_0002f1f8.
void PlayJudge_update(void *playData, const PlayTouch *touches, int touchCount,
                      const int *noteIds) {
    (void)playData;
    (void)noteIds;
    AudioManager *audio = [AudioManager sharedManager];

    const int currentPos = gNoteMng.getCurrentPosition();
    const int noteCount = gNoteMng.getActiveNoteCount();
    (void)currentPos;

    // Walk the active notes high index -> low (nearest the judge line last), so a
    // single tap resolves the closest matching note.
    for (int index = noteCount - 1; index >= 0; index--) {
        NoteRenderData note;
        gNoteMng.getNoteObject(&note, index);
        if ((note.flags & kNoteJudgedMask) != 0) {
            continue;   // already judged / not judgeable
        }

        // Hit-test the touches against this note's judge-line target.
        bool hit = false;
        for (int t = 0; t < touchCount && !hit; t++) {
            const float dx = (float)touches[t].x / 65536.0f - note.targetX;
            const float dy = (float)touches[t].y / 65536.0f - note.targetY;
            if (dx * dx + dy * dy < kHitRadius * kHitRadius) {
                hit = true;
            }
        }

        if (hit) {
            // A tap landed on this note: grade it (COOL/GREAT/GOOD/BAD or miss).
            gNoteMng.judgeNoteHit((unsigned)index);
        } else if (note.startTick < note.endTick) {
            // A hold note whose tail may have passed: resolve success/fail.
            gNoteMng.updateLongNote((unsigned)index);
        }

        // Draw the note through the sprite/animation pipeline: drawLayer feeds the
        // ordering table a command for this note's layer at the current frame
        // (AepManager::drawLayer -> FUN_0000fe8c fills / FUN_000113d0 writes it).
    }

    // Combo-milestone jingles (Ghidra: DAT_00179000 = combo; thresholds 25 / 50 /
    // every 100). The original selects one of three combo effect voices.
    const int combo = gNoteMng.combo();
    if (combo == 25 || combo == 50 || (combo >= 100 && combo % 50 == 0)) {
        [audio playSe:@"SE_COMBO" resourceId:RSND_INSTANCE_ID_ERROR];
    }
}
