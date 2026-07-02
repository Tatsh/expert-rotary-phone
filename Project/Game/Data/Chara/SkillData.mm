//
//  SkillData.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  The 30 built-in Sugoroku skill definitions: a constant-NSString description
//  plus a random-selection weight (table @ 0x133478; descriptions are UTF-16
//  constant strings @ 0x12d9c0..). Every Japanese description carries an inline
//  English translation.
//

#include <cassert>

#import "SkillData.h"

// The outer table (Ghidra: @ 0x133478). Each entry is { NSString*, int weight };
// the first word points at the constant-NSString description.
static const SkillDataStruct kSkillData[kSkillCount] = {
    // Indices 0-6: force a specific roulette outcome (1 through 7).
    { @"【ルーレットで必ず1を出せる】", 100 },  //  0  [Always roll a 1 on the roulette]
    { @"【ルーレットで必ず2を出せる】", 100 },  //  1  [Always roll a 2 on the roulette]
    { @"【ルーレットで必ず3を出せる】", 100 },  //  2  [Always roll a 3 on the roulette]
    { @"【ルーレットで必ず4を出せる】", 100 },  //  3  [Always roll a 4 on the roulette]
    { @"【ルーレットで必ず5を出せる】", 100 },  //  4  [Always roll a 5 on the roulette]
    { @"【ルーレットで必ず6を出せる】", 100 },  //  5  [Always roll a 6 on the roulette]
    { @"【ルーレットで必ず7を出せる】", 100 },  //  6  [Always roll a 7 on the roulette]
    { @"【スタートマスに移動】", 50 },          //  7  [Move to the start space]
    { @"【１つ前の分かれ道に戻る】", 50 },      //  8  [Go back to the previous fork]
    { @"【逆走】", 70 },                        //  9  [Reverse direction (run backwards)]
    { @"【赤い罠を無効化】", 30 },              // 10  [Nullify red traps]
    { @"【青い罠を無効化】", 30 },              // 11  [Nullify blue traps]
    { @"【緑の罠を無効化】", 30 },              // 12  [Nullify green traps]
    { @"【黄色い罠を無効化】", 30 },            // 13  [Nullify yellow traps]
    { @"【ルーレットの目が2倍に】", 50 },       // 14  [Roulette result doubled (x2)]
    { @"【ルーレットの目が3倍に】", 50 },       // 15  [Roulette result tripled (x3)]
    { @"【フレンドとの友好度上昇率UP】", 30 },  // 16  [Higher friendship-gain rate with friends]
    { @"【ほかのプレーヤーをマップに招待】", 30 }, // 17  [Invite other players onto the map]
    { @"【進む＆戻るマスを無効化】", 30 },      // 18  [Nullify advance & retreat spaces]
    { @"【全ての色の罠を無効化】", 60 },        // 19  [Nullify traps of every color]
    { @"【赤い罠に止まるとルーレット消費TPが減る】", 30 },  // 20  [Landing on a red trap lowers roulette TP cost]
    { @"【青い罠に止まるとルーレット消費TPが減る】", 30 },  // 21  [Landing on a blue trap lowers roulette TP cost]
    { @"【緑の罠に止まるとルーレット消費TPが減る】", 30 },  // 22  [Landing on a green trap lowers roulette TP cost]
    { @"【黄色の罠に止まるとルーレット消費TPが減る】", 30 }, // 23  [Landing on a yellow trap lowers roulette TP cost]
    { @"【暗闇を解除する】", 50 },              // 24  [Clear the darkness effect]
    { @"【マスの区別不能状態を解除する】", 50 }, // 25  [Clear the "spaces indistinguishable" state]
    { @"【ワープマスの封印を解除する】", 50 },  // 26  [Unseal warp spaces]
    { @"【出目を限定する罠を解除する】", 20 },  // 27  [Clear traps that restrict roulette outcomes]
    { @"【罠による足止めを解除する】", 20 },    // 28  [Clear trap-based immobilization]
    { @"【キャラチケットが貰える確率を上げる】", 80 }, // 29  [Raise the chance of earning a character ticket]
};

// Ghidra: FUN_000cb9d0 (asserts index < 30 at SkillData.mm:199).
const SkillDataStruct *GetSkillDataStruct(int index) {
    assert(index >= 0 && index < kSkillCount);
    return &kSkillData[index];
}

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
