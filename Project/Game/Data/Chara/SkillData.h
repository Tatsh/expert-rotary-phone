//
//  SkillData.h
//  pop'n rhythmin
//
//  The 30 built-in Sugoroku (board-game mode) skills. Reconstructed from Ghidra
//  project rb420, program PopnRhythmin.
//
//  Layout in the binary (all addresses are load addresses):
//    * Outer table @ 0x133478 — 30 x 8 bytes: { const Skill *skill; int weight; }
//      (GetSkillDataStruct, FUN_000cb9d0, asserts index < 30).
//    * Inner Skill objects @ 0x13aa48 — 30 x 16 bytes, statically constructed:
//      { vtable; int baseValue(=2000); const char16_t *description; int length; }
//      The vtable slot points into bss (0x1a7800, past end-of-file), i.e. it is
//      bound by the C++ static initializer at load — not reconstructed here.
//

#pragma once

#include <cstdint>

// One built-in skill. Polymorphic (the binary's objects carry a vtable), with a
// fixed base value (2000 for every built-in skill), a Japanese description in
// UTF-16, and that description's length in code units (cached at construction).
class Skill {
public:
    explicit Skill(const char16_t *description);
    virtual ~Skill() = default;

    int baseValue() const { return _baseValue; }              // ivar +0x4
    const char16_t *description() const { return _description; } // ivar +0x8
    int descriptionLength() const { return _descriptionLength; } // ivar +0xc

private:
    int _baseValue;                 // +0x4  (2000 for all built-in skills)
    const char16_t *_description;   // +0x8
    int _descriptionLength;         // +0xc
};

// One outer-table entry: a skill plus its random-selection weight.
struct SkillDataStruct {
    const Skill *skill;   // +0x0
    int weight;           // +0x4  (100/80/70/60/50/30/20)
};

// Number of built-in skills (Ghidra: bound checked as index < 0x1e).
constexpr int kSkillCount = 30;

// Bounds-checked accessor for the 30 built-in skills (asserts index < 30).
// Ghidra: GetSkillDataStruct @ FUN_000cb9d0.
const SkillDataStruct *GetSkillDataStruct(int index);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
