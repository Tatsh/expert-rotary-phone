//
//  SkillData.h
//  pop'n rhythmin
//
//  Hardcoded table of the 30 built-in skills. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin. Pure C++ (raw data, no Objective-C).
//

#pragma once

#include <cstdint>

// One skill record (Ghidra: 8-byte struct, table @ 0x133478). The exact field
// breakdown is not yet confirmed; modeled as two 32-bit fields.
struct SkillDataStruct {
    int32_t field0;  // +0x0
    int32_t field4;  // +0x4
};

// Bounds-checked accessor for the 30 built-in skills (asserts index < 30).
// Ghidra: GetSkillDataStruct @ 0xcb9d0
const SkillDataStruct *GetSkillDataStruct(int index);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
