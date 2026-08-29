/**
 * @file
 * @brief The boot-chain task constructors: the seams the launch and menu flow spawns tasks
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
 * @brief Create the boot logo splash task.
 * @return The new task.
 */
ne::C_TASK *BootCreateTask();
/**
 * @brief Create the main menu hub task.
 * @return The new task.
 */
ne::C_TASK *MenuCreateTask();
/**
 * @brief Create the title screen task.
 * @return The new task.
 */
ne::C_TASK *TitleTaskCreate();
/**
 * @brief Create the standard music-select task.
 * @return The new task.
 */
ne::C_TASK *MainTaskCreate();
/**
 * @brief Create the note-play task.
 * @return The new task.
 */
ne::C_TASK *PlayTaskCreate();
/**
 * @brief Create the arcade main task.
 * @return The new task.
 */
ne::C_TASK *AcMainTaskCreate();
/**
 * @brief Create the tutorial task.
 * @return The new task.
 * @ghidraAddress 0x2db10
 */
ne::C_TASK *TutorialTaskCreate();
/**
 * @brief Create the arcade-viewer note-play task.
 * @return The new task.
 * @ghidraAddress 0x215a0
 */
ne::C_TASK *AcViewerTaskCreate();
/**
 * @brief Create the title task the boot logo hands off to.
 * @return The new task.
 * @ghidraAddress 0x2b678
 */
ne::C_TASK *BootCreateNextTask();
/**
 * @brief Create the note-play result screen task, an operator_new(0x3a0) plus its constructor.
 * @return The new task.
 * @ghidraAddress 0x3d5bc
 */
ne::C_TASK *PlayResultCreateTask();

#endif /* TASKFACTORY_H */
