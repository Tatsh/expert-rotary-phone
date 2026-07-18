//
//  CharaManager.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Builds and queries the player's character lists. The hard-coded 30 come from
//  GetHardCodeCharaDataStruct; the rest are downloaded as chara_%03d.chr files
//  (BFCodec-encrypted JSON, same "Popn Orbit Note." key scheme as the .orb
//  data).
//

#include <cstdint>
#include <memory>
#include <vector>

#import "AcMainTask.h"
#import "AppDelegate.h"
#import "BFCodec.h"
#import "CharaData.h"
#import "CharaInfo.h"
#import "CharaManager.h"
#import "LimitedCharaInfo.h"
#import "MusicManager.h"
#import "PreferredCharaInfo.h"
#import "RhCrypto.h"
#import "RhUtil.h"
#import "UserSettingData.h"
#include "neTextureForiOS.h"

CharaManager gCharaManager;

// Ghidra: getCharaManager FUN_0002980c — a ___cxa_guard-protected one-shot that
// calls gCharaManager.reload() on first use, then returns the global. The C++
// function-local static reproduces the same construct-once guard semantics.
// @complete
CharaManager &CharaManagerShared() {
    static const bool once = [] {
        gCharaManager.reload();
        return true;
    }();
    static_cast<void>(once);
    return gCharaManager;
}

namespace {

// The obfuscated 25-byte key at DAT_0012fa0c. Deobfuscated as key[i]+i it
// spells "Popn Orbit Note. xjr1300."; its MD5 is the BFCodec key (see
// charaDecodeChr).
const uint8_t kCharaKeyObfuscated[25] = {
    0x50, 0x6E, 0x6E, 0x6B, 0x1C, 0x4A, 0x6C, 0x5B, 0x61, 0x6B, 0x16, 0x43, 0x63,
    0x67, 0x57, 0x1F, 0x10, 0x67, 0x58, 0x5F, 0x1D, 0x1E, 0x1A, 0x19, 0x16,
};

// Ghidra: FUN_0005c508 — deobfuscate the key (byte + index), MD5 it, then
// BFCodec-decipher the data in place. Returns the data on success, nil on fail.
// @complete
NSData *charaDecodeChr(NSMutableData *data) {
    const int length = static_cast<int>(sizeof(kCharaKeyObfuscated));
    std::vector<uint8_t> deob(length);
    for (int i = 0; i < length; i++) {
        deob[i] = static_cast<uint8_t>(kCharaKeyObfuscated[i] + static_cast<uint8_t>(i));
    }
    uint8_t digest[16];
    RhMD5(deob.data(), length, digest);

    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:(const char *)digest keyLength:16];
    if (![codec decipher:data]) {
        return nil;
    }
    return data;
}

// Ghidra: FUN_00028aa4 — treat an NSArray of NSNumber as a packed bitfield
// (32 bits per element) and test bit `bit`.
// @complete
bool charaTestGotBit(NSArray *bits, unsigned bit) {
    unsigned word = bit >> 5;
    if (word >= [bits count]) {
        return false;
    }
    int value = [bits[word] intValue];
    return (value & (1 << (bit & 0x1f))) != 0;
}

// Collect the "Id" values out of a JSON array of {"Id": n, ...} objects.
NSArray *collectIds(NSArray *entries) {
    NSMutableArray *ids = [NSMutableArray array];
    for (NSDictionary *entry in entries) {
        [ids addObject:entry[@"Id"]];
    }
    return ids;
}

} // namespace

// Ghidra: FUN_000b85bc.
// @complete
void CharaManager::reload() {
    NSMutableArray *preferred = [NSMutableArray array];
    NSMutableArray *limited = [NSMutableArray array];
    NSMutableArray *allChara = [NSMutableArray array];
    NSMutableArray *available = [NSMutableArray array];

    _preferred = nil;
    _limited = nil;
    _available = nil;

    // The 30 built-in characters.
    for (short i = 0; i < 30; i++) {
        const CharaDataStruct *d = GetHardCodeCharaDataStruct(i);
        CharaInfo *info = [[CharaInfo alloc] init];
        info.charaId = i;
        info.charaName = d->name;
        info.info = d->info;
        info.skillId = d->skillId;
        info.skillName = d->skillName;
        info.rarity = d->rarity;
        [allChara addObject:info];
    }

    // Every downloaded chara_%03d.chr (numbered 0..999, stop at the first gap).
    NSString *supportDir = [AppDelegate appAppSupportDirectory];
    for (int n = 0; n < 1000; n++) {
        NSString *name = [NSString stringWithFormat:@"chara_%03d.chr", n];
        NSString *path = [supportDir stringByAppendingPathComponent:name];
        if (!RhFileExists(path)) {
            break;
        }

        NSData *raw = [[NSData alloc] initWithContentsOfFile:path];
        NSMutableData *buffer = [NSMutableData dataWithData:raw];
        NSData *decoded = charaDecodeChr(buffer);
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:decoded
                                                             options:NSJSONReadingMutableContainers
                                                               error:nil];

        // "Preferred": music<->chara pairings that unlock preferred characters.
        for (NSDictionary *entry in json[@"Preferred"]) {
            NSArray *music = entry[@"Music"];
            NSArray *chara = entry[@"Chara"];
            if (music && chara && [music count] && [chara count]) {
                PreferredCharaInfo *pref = [[PreferredCharaInfo alloc] init];
                pref.musicIds = [collectIds(music) copy];
                pref.charaIds = [collectIds(chara) copy];
                [preferred addObject:pref];
            }
        }

        // "Limited": time-limited character sets (same shape as Preferred).
        for (NSDictionary *entry in json[@"Limited"]) {
            NSArray *music = entry[@"Music"];
            NSArray *chara = entry[@"Chara"];
            if (music && chara && [music count] && [chara count]) {
                LimitedCharaInfo *lim = [[LimitedCharaInfo alloc] init];
                lim.musicIds = [collectIds(music) copy];
                lim.charaIds = [collectIds(chara) copy];
                [limited addObject:lim];
            }
        }

        // "Chara": additional character records defined by the download.
        for (NSDictionary *entry in json[@"Chara"]) {
            CharaInfo *info = [[CharaInfo alloc] init];
            info.charaId = [entry[@"Id"] intValue];
            info.charaName = entry[@"Name"];
            info.info = entry[@"Info"];
            info.skillId = [entry[@"SkillId"] intValue];
            info.skillName = entry[@"SkillName"];
            info.rarity = [entry[@"Rarity"] intValue];
            [allChara addObject:info];
        }
    }

    _preferred = [preferred copy];
    _limited = [limited copy];

    // Keep only the characters the player can currently use.
    for (CharaInfo *info in allChara) {
        if (isCharaAvailable(static_cast<unsigned short>(info.charaId))) {
            [available addObject:info];
        }
    }
    _available = [available copy];
}

// Ghidra: FUN_000b9048. A character is available unless it belongs to a limited
// set that has not been unlocked (neither owned nor its music purchased).
// @complete
bool CharaManager::isCharaAvailable(unsigned short charaId) const {
    NSArray *gotChara = [UserSettingData gotCharaArray];
    bool inLimitedSet = false;

    for (LimitedCharaInfo *lim in _limited) {
        for (NSNumber *cid in lim.charaIds) {
            if (([cid shortValue] & 0xffff) != charaId) {
                continue;
            }
            inLimitedSet = true;
            // Owned outright -> available.
            if (charaTestGotBit(gotChara, [cid shortValue])) {
                return true;
            }
            // Otherwise available only if any associated music is purchased.
            for (NSNumber *mid in lim.musicIds) {
                NSString *path = [[MusicManager getInstance] getPathFromPurchased:[mid intValue]];
                if (RhFileExists(path)) {
                    return true;
                }
            }
        }
    }

    // Not in any limited set -> always available; in a set but locked -> not.
    return !inLimitedSet;
}

// Ghidra: FUN_000b9308 — linear search of the available list by charaId.
// @complete
CharaInfo *CharaManager::availableInfoForCharaId(short charaId) const {
    for (CharaInfo *info in _available) {
        if (info.charaId == charaId) {
            return info;
        }
    }
    return nil;
}

// Ghidra: FUN_000b93d0 — mark preferred sets whose music is now purchased and
// whose characters are owned, returning the ids that just unlocked.
// @complete
NSArray *CharaManager::collectUnlockedCharaIds() {
    NSMutableArray *unlocked = [NSMutableArray array];
    NSArray *gotChara = [UserSettingData gotCharaArray];

    for (PreferredCharaInfo *pref in _preferred) {
        if (!pref.getFlg) {
            for (NSNumber *mid in pref.musicIds) {
                NSString *path = [[MusicManager getInstance] getPathFromPurchased:[mid intValue]];
                if (RhFileExists(path)) {
                    for (NSNumber *cid in pref.charaIds) {
                        if (charaTestGotBit(gotChara, [cid shortValue])) {
                            pref.getFlg = YES;
                            break;
                        }
                    }
                    break;
                }
            }
        }
        if (!pref.getFlg) {
            for (NSNumber *cid in pref.charaIds) {
                [unlocked addObject:cid];
            }
        }
    }
    return [unlocked copy];
}

// ---------------------------------------------------------------------------
// Chara-select page-texture helpers. In the binary these are AcMainTask methods
// (@ 0xa27f0 / 0xa2a40 / 0xa2b10); reconstructed as free functions and declared
// friends of AcMainTask, they reach its private chara arrays/textures by name.
// The two chara NSArray slots are stored as raw (non-owning) void* on the task,
// so reads __bridge them without a retain.
// ---------------------------------------------------------------------------

// Ghidra: charaSelectLoadPageTextures @ 0xa27f0.
// @complete
void AcMainTask::charaSelectLoadPageTextures(int page) {
    __unsafe_unretained NSArray *available = (__bridge NSArray *)m_availableInfos;
    __unsafe_unretained NSArray *gotChara = (__bridge NSArray *)m_gotCharaArray;

    const int start = page * 6;
    for (int i = 0; i < 6; i++) {
        const auto idx = static_cast<unsigned>(start + i);
        if (idx >= static_cast<unsigned>([available count])) {
            break;
        }

        CharaInfo *info = available[idx];
        const int charaId = info.charaId;

        // Replace the occupant of the current-page texture slot (make_unique
        // frees any previous one).
        auto &slot = m_charaPageCurrTex[i];
        slot = std::make_unique<neTextureForiOS>();

        // Characters 0-29 are bundled resources; 30+ are downloaded to
        // the app-support directory.  Owned chars use the "open" art;
        // locked chars use the "lock" placeholder.
        BOOL owned =
            RhTestBitInNumberArray(gotChara, static_cast<unsigned>(static_cast<short>(charaId)));
        NSString *imageName =
            [NSString stringWithFormat:(owned ? @"open_chara_%03d.png" : @"lock_chara_%03d.png"),
                                       static_cast<int>(charaId)];

        NSString *path;
        if (charaId < 30) {
            path = [[NSBundle mainBundle] pathForResource:imageName ofType:nil];
        } else {
            path = [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:imageName];
        }
        slot->load([path UTF8String]);
    }
}

// Ghidra: charaSelectFindCharaIndex @ 0xa2a40.
// @complete
int AcMainTask::charaSelectFindCharaIndex(int charaId) {
    __unsafe_unretained NSArray *available = (__bridge NSArray *)m_availableInfos;
    int idx = 0;
    for (CharaInfo *info in available) {
        if (info.charaId == charaId) {
            return idx;
        }
        ++idx;
    }
    // Not found: faithful to the binary, which returns the total array count.
    // In practice the selected character is always in the available list.
    return idx;
}

// Ghidra: charaSelectReleaseTextures @ 0xa2b10.
// @complete
void AcMainTask::charaSelectReleaseTextures() {
    for (int i = 0; i < 6; i++) {
        m_charaPagePrevTex[i].reset();
        m_charaPageCurrTex[i].reset();
    }
    // Highlight texture (reserve slot 2 @ +0xf0).
    m_reserveTex[2].reset();
}

// Ghidra: countAvailableCharacters @ 0x28b10.
// The binary uses NEON SIMD to popcount each 32-bit word; __builtin_popcount
// produces the same result portably.
// @complete
int countAvailableCharacters(NSArray *gotCharaArray) {
    // Count the total number of owned characters (set bits in the gotChara
    // bitfield, where each NSNumber element holds 32 bits).
    unsigned totalOwned = 0;
    for (NSNumber *word in gotCharaArray) {
        totalOwned +=
            static_cast<unsigned>(__builtin_popcount(static_cast<unsigned>([word intValue])));
    }
    // Lazy-init gCharaManager if needed (binary calls getCharaManager() here).
    CharaManagerShared();
    NSUInteger available = [gCharaManager.availableInfos() count];
    // Return 1 when the player owns at least as many characters as are
    // currently available (all unlocked); 0 when there are still chars to
    // collect.
    return static_cast<int>(available <= static_cast<NSUInteger>(totalOwned));
}
