/**
 * @file
 * The boot-chain task constructors: the seams the launch and menu flow spawns tasks
 * through.
 *
 * Each is an operator_new(size) + ctor + setPriority(3) in the binary. Reconstructed from Ghidra
 * project rb420, program PopnRhythmin.
 */

#ifndef TASKFACTORY_H
#define TASKFACTORY_H

namespace ne {
class C_TASK;
}

/**
 * Create the boot logo splash task.
 * @return The new task.
 */
ne::C_TASK *BootCreateTask();
/**
 * Create the main menu hub task.
 * @return The new task.
 */
ne::C_TASK *MenuCreateTask();
/**
 * Create the main menu hub task for a return from song select.
 *
 * The same construction as MenuCreateTask() minus the info flag, so the mode-select hub does not
 * open the once-a-day official-info web view on this path.
 * @return The new task.
 */
ne::C_TASK *MenuReturnCreateTask();
/**
 * Create the title screen task.
 * @return The new task.
 */
ne::C_TASK *TitleTaskCreate();
/**
 * Create the standard music-select task.
 * @return The new task.
 */
ne::C_TASK *MainTaskCreate();
/**
 * Create the note-play task.
 * @return The new task.
 */
ne::C_TASK *PlayTaskCreate();
/**
 * Create the arcade main task.
 * @return The new task.
 */
ne::C_TASK *AcMainTaskCreate();
/**
 * Create the tutorial task.
 * @return The new task.
 * @ghidraAddress 0x2db10
 */
ne::C_TASK *TutorialTaskCreate();
/**
 * Create the arcade-viewer note-play task.
 * @return The new task.
 * @ghidraAddress 0x215a0
 */
ne::C_TASK *AcViewerTaskCreate();
/**
 * Create the title task the boot logo hands off to.
 * @return The new task.
 * @ghidraAddress 0x2b678
 */
ne::C_TASK *BootCreateNextTask();
/**
 * Create the note-play result screen task, an operator_new(0x3a0) plus its constructor.
 * @return The new task.
 * @ghidraAddress 0x3d5bc
 */
ne::C_TASK *PlayResultCreateTask();

#endif /* TASKFACTORY_H */
