//
//  SkillData.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  The 30 built-in Sugoroku skill definitions (descriptions @ 0x12d9c0..,
//  inner Skill objects @ 0x13aa48, outer weighted table @ 0x133478). Every
//  description and weight below was extracted from the binary; the description
//  length stored in each object equals the UTF-16 code-unit count and is
//  computed by the constructor rather than duplicated here.
//

#include <cassert>
#include <string>

#include "SkillData.h"

namespace {

// Every built-in skill shares this base value in the binary (inner object +0x4).
constexpr int kSkillBaseValue = 2000;

}  // namespace

Skill::Skill(const char16_t *description)
    : _baseValue(kSkillBaseValue),
      _description(description),
      _descriptionLength(static_cast<int>(std::char_traits<char16_t>::length(description))) {}

// The 30 built-in Skill objects (Ghidra: inner table @ 0x13aa48). Order and
// descriptions are verbatim from the binary; indices 0-6 are the roulette
// "always roll N" skills, 7-29 are the board-hazard / utility skills.
static const Skill kSkills[kSkillCount] = {
    // Indices 0-6: force a specific roulette outcome (1 through 7).
    Skill(u"【ルーレットで必ず1を出せる】"),        //  0  [Always roll a 1 on the roulette]
    Skill(u"【ルーレットで必ず2を出せる】"),        //  1  [Always roll a 2 on the roulette]
    Skill(u"【ルーレットで必ず3を出せる】"),        //  2  [Always roll a 3 on the roulette]
    Skill(u"【ルーレットで必ず4を出せる】"),        //  3  [Always roll a 4 on the roulette]
    Skill(u"【ルーレットで必ず5を出せる】"),        //  4  [Always roll a 5 on the roulette]
    Skill(u"【ルーレットで必ず6を出せる】"),        //  5  [Always roll a 6 on the roulette]
    Skill(u"【ルーレットで必ず7を出せる】"),        //  6  [Always roll a 7 on the roulette]
    Skill(u"【スタートマスに移動】"),              //  7  [Move to the start space]
    Skill(u"【１つ前の分かれ道に戻る】"),          //  8  [Go back to the previous fork]
    Skill(u"【逆走】"),                            //  9  [Reverse direction (run backwards)]
    Skill(u"【赤い罠を無効化】"),                  // 10  [Nullify red traps]
    Skill(u"【青い罠を無効化】"),                  // 11  [Nullify blue traps]
    Skill(u"【緑の罠を無効化】"),                  // 12  [Nullify green traps]
    Skill(u"【黄色い罠を無効化】"),                // 13  [Nullify yellow traps]
    Skill(u"【ルーレットの目が2倍に】"),           // 14  [Roulette result doubled (x2)]
    Skill(u"【ルーレットの目が3倍に】"),           // 15  [Roulette result tripled (x3)]
    Skill(u"【フレンドとの友好度上昇率UP】"),      // 16  [Higher friendship-gain rate with friends]
    Skill(u"【ほかのプレーヤーをマップに招待】"),  // 17  [Invite other players onto the map]
    Skill(u"【進む＆戻るマスを無効化】"),          // 18  [Nullify advance & retreat spaces]
    Skill(u"【全ての色の罠を無効化】"),            // 19  [Nullify traps of every color]
    Skill(u"【赤い罠に止まるとルーレット消費TPが減る】"),  // 20  [Landing on a red trap lowers roulette TP cost]
    Skill(u"【青い罠に止まるとルーレット消費TPが減る】"),  // 21  [Landing on a blue trap lowers roulette TP cost]
    Skill(u"【緑の罠に止まるとルーレット消費TPが減る】"),  // 22  [Landing on a green trap lowers roulette TP cost]
    Skill(u"【黄色の罠に止まるとルーレット消費TPが減る】"), // 23  [Landing on a yellow trap lowers roulette TP cost]
    Skill(u"【暗闇を解除する】"),                  // 24  [Clear the darkness effect]
    Skill(u"【マスの区別不能状態を解除する】"),    // 25  [Clear the "spaces indistinguishable" state]
    Skill(u"【ワープマスの封印を解除する】"),      // 26  [Unseal warp spaces]
    Skill(u"【出目を限定する罠を解除する】"),      // 27  [Clear traps that restrict roulette outcomes]
    Skill(u"【罠による足止めを解除する】"),        // 28  [Clear trap-based immobilization]
    Skill(u"【キャラチケットが貰える確率を上げる】"), // 29  [Raise the chance of earning a character ticket]
};

// The outer weighted table (Ghidra: @ 0x133478). Each entry pairs a skill with
// its random-selection weight (decoded from the second word of each 8-byte slot).
static const SkillDataStruct kSkillData[kSkillCount] = {
    { &kSkills[0],  100 }, { &kSkills[1],  100 }, { &kSkills[2],  100 },
    { &kSkills[3],  100 }, { &kSkills[4],  100 }, { &kSkills[5],  100 },
    { &kSkills[6],  100 }, { &kSkills[7],   50 }, { &kSkills[8],   50 },
    { &kSkills[9],   70 }, { &kSkills[10],  30 }, { &kSkills[11],  30 },
    { &kSkills[12],  30 }, { &kSkills[13],  30 }, { &kSkills[14],  50 },
    { &kSkills[15],  50 }, { &kSkills[16],  30 }, { &kSkills[17],  30 },
    { &kSkills[18],  30 }, { &kSkills[19],  60 }, { &kSkills[20],  30 },
    { &kSkills[21],  30 }, { &kSkills[22],  30 }, { &kSkills[23],  30 },
    { &kSkills[24],  50 }, { &kSkills[25],  50 }, { &kSkills[26],  50 },
    { &kSkills[27],  20 }, { &kSkills[28],  20 }, { &kSkills[29],  80 },
};

// Ghidra: FUN_000cb9d0 (asserts index < 30 at SkillData.mm:199).
const SkillDataStruct *GetSkillDataStruct(int index) {
    assert(index >= 0 && index < kSkillCount);
    return &kSkillData[index];
}

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
