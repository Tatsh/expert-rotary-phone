//
//  TaskFactory.mm
//  pop'n rhythmin
//
//  The boot-chain task constructors: the seams the launch/menu flow spawns tasks
//  through, wired to the reconstructed task classes. Reconstructed from Ghidra
//  project rb420, program PopnRhythmin — each is an operator_new(<size>) + ctor +
//  setPriority(3) in the original.
//

#import "AcMainTask.h"
#import "BootLogoTask.h"
#import "C_TASK.h"
#import "MainTask.h"
#import "MenuMainTask.h"
#import "PlayTask.h"
#import "TitleTask.h"

// App boot: create + register the logo splash task at priority 3. Ghidra:
// neEngine::startBootTask (operator_new(0x4c) + BootLogoTask_ctor + setPriority(3)).
C_TASK *BootCreateTask() {
    auto *task = new BootLogoTask();
    task->setPriority(3);
    return task;
}

// TitleTask -> the mode-select hub. Ghidra: operator_new(0x1b0) + MenuMainTask_ctor +
// MenuMainTask_setInfoFlag(1) + setPriority(3) (BootLogoTask_finish/TitleTask_finish).
C_TASK *MenuCreateTask() {
    auto *task = new MenuMainTask();
    task->setInfoFlag(true);   // FUN_0006d194(_, 1)
    return task;               // the caller sets priority 3
}

// MenuMainTask -> relaunch the title. Ghidra: operator_new(0x54) + TitleTask_ctor.
C_TASK *TitleTaskCreate() {
    return new TitleTask();
}

// MenuMainTask (standard play button) -> the music-select task. Ghidra:
// operator_new(0xaa8) + MainTask_ctor (FUN_00034d48).
C_TASK *MainTaskCreate() {
    return new MainTask();
}

// MainTask (song chosen) -> the note-play task. Ghidra: PlayTask (state @ +0x9fc,
// update PlayTask_update FUN_0002dc14) — drives the PlayJudge/NoteMng core.
C_TASK *PlayTaskCreate() {
    return new PlayTask();
}

// MenuMainTask (arcade button) -> the arcade select+play task. Ghidra:
// operator_new(0x9fc) + AcMainTask_ctor (FUN_00099ab0) — drives AcNoteMng.
C_TASK *AcMainTaskCreate() {
    return new AcMainTask();
}
