//
//  TaskFactory.mm
//  pop'n rhythmin
//
//  The boot-chain task constructors: the seams the launch/menu flow spawns
//  tasks through, wired to the reconstructed task classes. Reconstructed from
//  Ghidra project rb420, program PopnRhythmin — each is an operator_new(<size>)
//  + ctor + setPriority(3) in the original.
//

#import "AcMainTask.h"
#import "AcViewerTask.h"
#import "BootLogoTask.h"
#import "C_TASK.h"
#import "MainTask.h"
#import "MenuMainTask.h"
#import "PlayTask.h"
#import "TitleTask.h"

// App boot: create + register the logo splash task at priority 3. Ghidra:
// neEngine::startBootTask (operator_new(0x4c) + BootLogoTask_ctor +
// setPriority(3)).
C_TASK *BootCreateTask() {
    auto *task = new BootLogoTask();
    task->setPriority(3);
    return task;
}

// TitleTask -> the mode-select hub. Ghidra: operator_new(0x1b0) +
// MenuMainTask_ctor + MenuMainTask_setInfoFlag(1) + setPriority(3)
// (BootLogoTask_finish/TitleTask_finish).
C_TASK *MenuCreateTask() {
    auto *task = new MenuMainTask();
    task->setInfoFlag(true); // FUN_0006d194(_, 1)
    return task;             // the caller sets priority 3
}

// MenuMainTask -> relaunch the title. Ghidra: operator_new(0x54) +
// TitleTask_ctor.
C_TASK *TitleTaskCreate() {
    return new TitleTask();
}

// MenuMainTask (standard play button) -> the music-select task. Ghidra:
// operator_new(0xaa8) + MainTask_ctor (FUN_00034d48).
C_TASK *MainTaskCreate() {
    return new MainTask();
}

// MainTask (song chosen) -> the note-play task. Ghidra: PlayTask (state @
// +0x9fc, update PlayTask_update FUN_0002dc14) — drives the PlayJudge/NoteMng
// core.
C_TASK *PlayTaskCreate() {
    return new PlayTask();
}

// MenuMainTask (arcade button) -> the arcade select+play task. Ghidra:
// operator_new(0x9fc) + AcMainTask_ctor (FUN_00099ab0) — drives AcNoteMng.
C_TASK *AcMainTaskCreate() {
    return new AcMainTask();
}

// MainTask/MenuMainTask (tutorial) -> a PlayTask running the tutorial chart.
// Ghidra: FUN_0002db10 is PlayTask_ctor (PlayTask_update vtable, 0x9d4 play
// data).
C_TASK *TutorialTaskCreate() {
    return new PlayTask();
}

// MenuMainTask (arcade-viewer button) -> the arcade-viewer note-play task.
// Ghidra: FUN_000215a0 is AcViewerTask_ctor (operator_new(0x210) + memset
// 0x1e8; distinct vtable @ 0x130bb8, update FUN_00021678). It is NOT AcMainTask
// (ctor FUN_00099ab0, 0x9fc bytes, vtable @ 0x1327c8): Ghidra only labels this
// vtable acMainTask* because AppDelegate holds the task in its `acMainTask`
// property. The +0x168 menu button spawns this.
C_TASK *AcViewerTaskCreate() {
    return new AcViewerTask();
}

// BootLogoTask_finish hands off to the title task. Ghidra: FUN_0002b678 is
// TitleTask_ctor; the boot path is operator_new(0x54) + ctor + setPriority(3).
C_TASK *BootCreateNextTask() {
    auto *task = new TitleTask();
    task->setPriority(3);
    return task;
}
