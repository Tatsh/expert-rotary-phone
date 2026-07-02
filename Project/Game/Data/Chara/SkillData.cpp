//
//  SkillData.cpp
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#include <cassert>

#include "SkillData.h"

// The 30 built-in skills (Ghidra: table @ 0x133478). TODO: extract the exact
// entries; each is an 8-byte SkillDataStruct.
static const SkillDataStruct kSkillData[30] = {};

// Ghidra: @ 0xcb9d0 (asserts index < 30).
const SkillDataStruct *GetSkillDataStruct(int index) {
    assert(index >= 0 && index < 30);
    return &kSkillData[index];
}
