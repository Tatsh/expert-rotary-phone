//
//  SkillData.h
//  pop'n rhythmin
//
//  The 30 built-in Sugoroku (board-game mode) skill descriptions. Reconstructed
//  from Ghidra project rb420, program PopnRhythmin.
//
//  Table @ 0x133478 — 30 x 8 bytes: { NSString *description; int weight; }.
//  Each description is a constant NSString (isa =
//  ___CFConstantStringClassReference at the load-bound 0x1a7800; UTF-16
//  payload). GetSkillDataStruct (FUN_000cb9d0) returns &table[index] and
//  asserts index < 30.
//

#pragma once

#import <Foundation/Foundation.h>

/**
 * @brief One built-in skill: its description and its random-selection weight.
 */
struct SkillDataStruct {
    NSString *description; /**< +0x0 The description, a constant Japanese NSString. */
    int weight;            /**< +0x4 The random-selection weight: 100, 80, 70, 60, 50, 30 or 20. */
};

/**
 * @brief The number of built-in skills. Ghidra bound-checks this as `index < 0x1e`.
 */
constexpr int kSkillCount = 30;

/**
 * @brief Bounds-checked accessor for the built-in skills.
 * @param index The skill index; asserts it is below kSkillCount.
 * @return The skill record.
 * @ghidraAddress 0xcb9d0
 */
const SkillDataStruct *GetSkillDataStruct(int index);

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
