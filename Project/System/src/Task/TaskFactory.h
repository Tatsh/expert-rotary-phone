//
//  TaskFactory.h
//  pop'n rhythmin
//
//  The boot-chain task constructors: the seams the launch/menu flow spawns tasks
//  through. Each is an operator_new(<size>) + ctor + setPriority(3) in the binary.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#ifndef TASKFACTORY_H
#define TASKFACTORY_H

class C_TASK;

C_TASK *BootCreateTask();       // boot logo splash
C_TASK *MenuCreateTask();       // main menu hub
C_TASK *TitleTaskCreate();      // title screen
C_TASK *MainTaskCreate();       // standard music-select
C_TASK *PlayTaskCreate();       // note-play
C_TASK *AcMainTaskCreate();     // arcade main
C_TASK *TutorialTaskCreate();   // tutorial (FUN_0002db10)
C_TASK *SugorokuMainTaskCreate(); // sugoroku board (FUN_000215a0)
C_TASK *BootCreateNextTask();   // the title task the boot logo hands off to (FUN_0002b678)
C_TASK *PlayResultCreateTask(); // note-play result screen (operator_new(0x3a0) + FUN_0003d5bc)

#endif /* TASKFACTORY_H */

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
