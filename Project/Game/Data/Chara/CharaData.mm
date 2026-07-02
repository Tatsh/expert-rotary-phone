//
//  CharaData.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#include <cassert>

#import "CharaData.h"

// The 30 built-in characters (Ghidra: table @ 0x133298).
// TODO: extract the exact 30 entries (name / info / skillName / skillId /
// rarity) from the binary; each is a 16-byte CharaDataStruct.
static const CharaDataStruct kCharaData[30] = {};

// Ghidra: @ 0xcb958 (asserts (index & 0xffff) < 30).
const CharaDataStruct *GetHardCodeCharaDataStruct(int index) {
    assert((index & 0xffff) < 30);
    return &kCharaData[index];
}
