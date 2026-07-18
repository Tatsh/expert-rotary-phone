//
//  CharaData.h
//  pop'n rhythmin
//
//  Hardcoded table of the 30 built-in characters. Reconstructed from Ghidra
//  project rb420, program PopnRhythmin (Objective-C++: entries hold NSStrings).
//

#pragma once

#import <Foundation/Foundation.h>

// One built-in character record (Ghidra: 16-byte struct, table @ 0x133298).
struct CharaDataStruct {
    NSString *name;      // +0x00
    NSString *info;      // +0x04
    NSString *skillName; // +0x08
    short skillId;       // +0x0c
    short rarity;        // +0x0e
};

/**
 * @brief Get the built-in character data for the given index (0..29).
 * @param index 0-based index of the built-in character (0..29).
 * @return Pointer to the CharaDataStruct for the built-in character at the given index.
 * @ghidraAddress 0xcb958
 */
const CharaDataStruct *GetHardCodeCharaDataStruct(int index);

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
