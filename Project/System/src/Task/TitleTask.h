//
//  TitleTask.h
//  pop'n rhythmin
//
//  The title screen + first-run flow task, spawned by BootLogoTask after the
//  logo splash. Plays the title BGM, shows the version, and drives the
//  first-run gate (policy acceptance -> conversion code -> DL file-list check
//  -> default download
//  -> version-update check) before handing off to the main-menu task.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (ctor
//  TitleTask_ctor FUN_0002b678, update FUN_0002b838, setup FUN_0002c084, finish
//  FUN_0002c3d0).
//
//  Objective-C++ (ARC-off, matching the engine): drives UIKit through the
//  bridged root view controller. Compiled only via TitleTask.mm.
//

#pragma once

#import <Foundation/Foundation.h>

#include "C_TASK.h"

@class CustomButton;
class AepManager;
class AepLyrCtrl; // the title screen's animated sprite layer (Ghidra ctor
                  // FUN_0002c7d8)

class TitleTask : public ne::C_TASK {
public:
    /// @brief Construct the title / first-run task (spawned by BootLogoTask::finish).
    /// @note Ghidra: TitleTask::TitleTask (FUN_0002b678).
    TitleTask();

    /// @brief Detach the conversion button from its superview, then run the base
    ///        task teardown.
    /// @note Ghidra: TitleTask::~TitleTask (FUN_0002b6b0).
    ~TitleTask() override;

    /// @brief Per-frame tick: drive the 10-state title / first-run machine, then
    ///        advance and draw the title AEP layers and the version label.
    /// @param deltaMs Frame delta (unused by this task; passed by the base scheduler).
    /// @note Ghidra: TitleTask::update (FUN_0002b838).
    void update(int deltaMs) override;

private:
    void setup();                 // Ghidra: TitleTask::setup (FUN_0002c084)
    void finish();                // Ghidra: TitleTask::finish (FUN_0002c3d0)
    void drawSoundTestLabel();    // Ghidra: TitleTask::drawSoundTestLabel (FUN_0002c52c)
    bool tapReleased() const;     // a touch released with < 11 px travel = a tap
    void buildConversionButton(); // state-3 UI: the "conversion" button + code alert

    AepManager *m_aep = nullptr;            // +0x28 render manager
    AepLyrCtrl *m_titleLayer = nullptr;     // +0x30 title animated sprite layer
    NSArray *m_dlFileList = nil;            // +0x34 DownloadMain's file-list result
    NSString *m_versionLabel = nil;         // +0x38 retained "Ver <n>"
    int m_titleSe = 0;                      // +0x3c title SE handle
    int m_soundTestLabelX = 0;              // +0x40 version-label draw x (0x19 phone / 0x24 iPad)
    bool m_needUpdate = false;              // +0x44 an app update is required
    bool m_soundTestHidden = false;         // +0x45 suppress the version / sound-test label
    int m_state = 0;                        // +0x48 state machine (0..9)
    bool m_state3Built = false;             // +0x4c the title UI has been built
    CustomButton *m_conversionButton = nil; // +0x50 the code-conversion button
};

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
