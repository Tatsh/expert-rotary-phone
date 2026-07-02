//
//  AcMainTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The arcade-mode
//  task. AcMainTask_update (FUN_00099d18) is ~24 KB (the app's largest function);
//  its full state machine is a large deferred unit — this carries the ctor and the
//  state-machine shell that drives the reconstructed AcNoteMng engine.
//

#import "AcMainTask.h"
#import "AcNoteMng.h"
#import "AepManager.h"
#import "AudioManager.h"
#import "neGraphics.h"

// Ghidra: AcMainTask_ctor (FUN_00099ab0) — base C_TASK ctor, a sub-object init
// (FUN_00062b20 @ +0x4f4), memset the 0x9d4-byte arcade play data, and set a few
// sentinels (+0x508 = -1, +0x62c = -0x63, +0x5a0 = 3).
AcMainTask::AcMainTask() = default;

// Ghidra: AcMainTask_update (FUN_00099d18) — the arcade select+play state machine.
// It mirrors the standard MainTask -> PlayTask flow (song/option select, then note
// play through AcNoteMng with the arcade hi-speed + judge windows) and hands off to
// the arcade result screen.
//
// NOT YET RECONSTRUCTED. This is the single largest function in the binary (~24 KB);
// a faithful reconstruction requires reverse-engineering its full state table, which
// is a dedicated unit tracked in STUBS.md — deliberately left empty here rather than
// filled with an unverified skeleton or manager fetches that do nothing. The arcade
// note engine it will drive (AcNoteMng) is already reconstructed, as is the parallel
// standard-mode flow (MenuMainTask / MainTask / PlayTask) it mirrors.
void AcMainTask::update(int /*deltaMs*/) {
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
