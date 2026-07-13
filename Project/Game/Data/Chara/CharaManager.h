//
//  CharaManager.h
//  pop'n rhythmin
//
//  Owns the three character lists the game builds at startup and after any
//  download. Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  In the binary this is a global 12-byte struct at DAT_00187d98 (three ObjC
//  array pointers) operated on by free functions that take its address; modeled
//  here as a C++ class with a single global instance (gCharaManager). The three
//  members are, in order: preferred sets, limited sets, and the filtered list
//  of characters currently available to the player.
//    * reload()                      = FUN_000b85bc
//    * isCharaAvailable()            = FUN_000b9048 (private helper)
//    * availableInfos()              = FUN_000b9304
//    * availableInfoForCharaId()     = FUN_000b9308
//    * collectUnlockedCharaIds()     = FUN_000b93d0
//

#pragma once

#import <Foundation/Foundation.h>

@class CharaInfo;

class CharaManager {
public:
    // Rebuild all three lists: the 30 hard-coded characters plus every character
    // and preferred/limited set found in the downloaded chara_%03d.chr files.
    void reload();

    // The characters currently available to the player (member +0x8).
    NSArray *availableInfos() const {
        return _available;
    }

    // The available CharaInfo whose charaId matches, or nil.
    CharaInfo *availableInfoForCharaId(short charaId) const;

    // Walk the preferred sets, mark any whose unlock condition is now met, and
    // return the character ids that just became unlocked (for reveal effects).
    NSArray *collectUnlockedCharaIds();

private:
    // True unless `charaId` is a limited character that has not been unlocked
    // (i.e. it is not owned and none of its associated music has been purchased).
    bool isCharaAvailable(unsigned short charaId) const;

    NSArray *_preferred = nil; // +0x0  PreferredCharaInfo objects
    NSArray *_limited = nil;   // +0x4  LimitedCharaInfo objects
    NSArray *_available = nil; // +0x8  CharaInfo objects (player-available)
};

// The single global instance (Ghidra: DAT_00187d98).
extern CharaManager gCharaManager;

// Ensure the global chara lists are built exactly once (lazy first-use guard),
// then return the instance. Ghidra: FUN_0002980c — a ___cxa_guard-protected
// one-shot around gCharaManager.reload() (FUN_000b85b8).
CharaManager &CharaManagerShared();

// ---------------------------------------------------------------------------
// Chara-select page-texture helpers (Ghidra rb420).
// Called by AcMainSugorokuDraw (FUN_000a3724) and AcMainTask::update
// (FUN_00099d18), which live in a different translation unit from
// CharaManager.mm, so these must be declared in this shared header.
// ---------------------------------------------------------------------------

// Forward-declare the arcade scene type; its full definition is in
// AcMainTask.h.
class AcMainTask;

// Load (or reload) the 6 character thumbnail textures for page `page` into
// the current-page texture array at AcMainTask +0x18c. Chooses
// "open_chara_%03d.png" for owned characters and "lock_chara_%03d.png" for
// locked ones; built-in chars (id < 30) are resolved from the main bundle,
// downloaded chars from the app-support directory.
// Ghidra: charaSelectLoadPageTextures @ 0xa27f0.
void charaSelectLoadPageTextures(AcMainTask *task, int page);

// Return the index in the available-chara array (AcMainTask +0x634) of the
// entry whose charaId matches `charaId`.  Returns the array count when not
// found (faithful to binary behaviour — the selected char is always present).
// Ghidra: charaSelectFindCharaIndex @ 0xa2a40.
int charaSelectFindCharaIndex(AcMainTask *task, int charaId);

// Delete and null out all textures in the prev-page array (AcMainTask +0x174,
// 6 slots), the current-page array (+0x18c, 6 slots), and the highlight
// texture (+0xf0).  Called during scene teardown.
// Ghidra: charaSelectReleaseTextures @ 0xa2b10.
void charaSelectReleaseTextures(AcMainTask *task);

// Popcount all 32-bit words in `gotCharaArray` (the NSArray of NSNumber
// produced by [UserSettingData gotCharaArray]) and return 1 when the total
// number of set bits (owned characters) is >= [gCharaManager.availableInfos()
// count] — i.e. the player owns all currently available characters.  Returns
// 0 when there are still characters to collect.
// Ghidra: countAvailableCharacters @ 0x28b10 (4 xrefs).
int countAvailableCharacters(NSArray *gotCharaArray);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
