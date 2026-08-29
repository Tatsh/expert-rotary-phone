/**
 * @file
 * The owner of the three character lists the game builds at startup and after any
 * download.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 *
 * In the binary this is a global 12-byte struct at DAT_00187d98 (three Objective-C array
 * pointers) operated on by free functions that take its address; it is modelled here as a C++
 * class with a single global instance (gCharaManager). The three members are, in order: preferred
 * sets, limited sets, and the filtered list of characters currently available to the player.
 *
 * - reload() = FUN_000b85bc
 * - isCharaAvailable() = FUN_000b9048 (private helper)
 * - availableInfos() = FUN_000b9304
 * - availableInfoForCharaId() = FUN_000b9308
 * - collectUnlockedCharaIds() = FUN_000b93d0
 */

#pragma once

#import <Foundation/Foundation.h>

@class CharaInfo;

/**
 * Owns the three character lists the game builds at startup and after any download:
 * preferred sets, limited sets, and the filtered list currently available to the player.
 */
class CharaManager {
public:
    /**
     * Rebuild all three lists: the 30 hard-coded characters plus every character and
     * preferred or limited set found in the downloaded chara_%03d.chr files.
     * @ghidraAddress 0xb85bc
     */
    void reload();

    /**
     * The characters currently available to the player (member +0x8).
     * @return An NSArray of CharaInfo.
     * @ghidraAddress 0xb9304
     */
    NSArray *availableInfos() const {
        return _available;
    }

    /**
     * The available character with a matching id.
     * @param charaId The character id to find.
     * @return The CharaInfo, or nil when the character is not available.
     * @ghidraAddress 0xb9308
     */
    CharaInfo *availableInfoForCharaId(short charaId) const;

    /**
     * Walk the preferred sets and mark any whose unlock condition is now met.
     * @return The character ids that just became unlocked, for the reveal effects.
     * @ghidraAddress 0xb93d0
     */
    NSArray *collectUnlockedCharaIds();

private:
    // True unless `charaId` is a limited character that has not been unlocked
    // (i.e. it is not owned and none of its associated music has been purchased).
    bool isCharaAvailable(unsigned short charaId) const;

    NSArray *_preferred = nil; // +0x0  PreferredCharaInfo objects
    NSArray *_limited = nil;   // +0x4  LimitedCharaInfo objects
    NSArray *_available = nil; // +0x8  CharaInfo objects (player-available)
};

/**
 * The single global instance (Ghidra: DAT_00187d98).
 */
extern CharaManager gCharaManager;

/**
 * Ensure the global character lists are built exactly once, behind a lazy first-use guard.
 *
 * Ghidra: FUN_0002980c, a ___cxa_guard-protected one-shot around gCharaManager.reload()
 * (FUN_000b85b8).
 * @return The global instance.
 */
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

// The chara-select page-texture helpers (charaSelectLoadPageTextures @ 0xa27f0,
// charaSelectFindCharaIndex @ 0xa2a40, charaSelectReleaseTextures @ 0xa2b10) are
// AcMainTask methods; they are declared on AcMainTask and defined in
// CharaManager.mm.

/**
 * Whether the player owns every currently-available character.
 *
 * Popcounts all 32-bit words in @p gotCharaArray and compares the total number of set bits (owned
 * characters) against `[gCharaManager.availableInfos() count]`.
 * @param gotCharaArray The NSArray of NSNumber produced by +[UserSettingData gotCharaArray].
 * @return 1 when every available character is owned, 0 when there are still some to collect.
 * @ghidraAddress 0x28b10
 */
int countAvailableCharacters(NSArray *gotCharaArray);

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
