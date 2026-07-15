//
//  TitleTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The title
//  screen
//  + first-run flow, handed off from BootLogoTask.
//

#import <UIKit/UIKit.h>

#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "CharaManager.h"
#import "CommonAlertView.h"
#import "CustomButton.h"
#import "DownloadMain.h"
#import "MainViewController.h" // the concrete root VC the title flow drives (Goto*/Communicating)
#import "TaskFactory.h"
#import "TitleTask.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"

// MenuCreateTask is declared in TaskFactory.h.

// Ghidra: TitleTask_ctor (FUN_0002b678) — base C_TASK ctor + zeroed fields.
TitleTask::TitleTask() = default;

/**
 * TitleTask dtor — detach the conversion button from its superview before the
 * base source-node teardown; ARC releases the other members. The
 * compiler-implicit dtor would drop m_conversionButton without removing it from
 * the view hierarchy, so this behaviour is reproduced explicitly.
 * @ghidraAddress 0x2b6b0
 * @complete
 */
TitleTask::~TitleTask() {
    if (m_conversionButton != nil) {
        [m_conversionButton removeFromSuperview];
        m_conversionButton = nil;
    }
}

// The root navigation view controller the flow drives (bridged from the
// engine). During the title flow the engine's root is the MainViewController
// (the binary dispatches Goto*/ InsertCommunicating/etc. to it dynamically);
// type it as such so those calls resolve.
static MainViewController *RootVC() {
    return (MainViewController *)neSceneManager::rootViewController();
}

// A touch released this frame that barely moved (< 11 px in x and y) counts as
// a tap (Ghidra: the touch-pool scan at the top of TitleTask_update).
bool TitleTask::tapReleased() const {
    neGraphics &gfx = neGraphics::shared();
    int count = gfx.activeTouchCount();
    for (int i = 0; i < count; i++) {
        const neTouchPoint *t = gfx.touchAt(i);
        if (t == nullptr || t->released == 0) {
            continue;
        }
        int dx = t->startX - t->x; // +0x04 down vs +0x0c current
        int dy = t->startY - t->y;
        if (dx < 0) {
            dx = -dx;
        }
        if (dy < 0) {
            dy = -dy;
        }
        if (dx < 0xb && dy < 0xb) {
            return true;
        }
    }
    return false;
}

/**
 * TitleTask_setup — cache the render manager, build the "Ver%@" label, load the
 * device-specific title scene + its image folder, and load + start the title SE
 * and looping BGM.
 * @ghidraAddress 0x2c084
 * @complete
 */
void TitleTask::setup() {
    m_aep = &AepManager::shared();
    m_versionLabel = [NSString stringWithFormat:@"Ver%@", AppDelegate.appDelegate.appVersion];

    const char *imageFolder;
    if (!neSceneManager::isPadDisplay()) {
        m_aep->loadAepDataDefaultPath(1, "title");
        m_soundTestLabelX = 0x19;
        imageFolder = (AppDelegate.appDelegate.displayType == 2) ? "1136IMG" : "640IMG";
    } else {
        m_aep->loadAepDataDefaultPath(1, "title_ipad");
        m_soundTestLabelX = 0x24;
        imageFolder = "IMG_IPAD";
    }
    m_titleLayer = new AepLyrCtrl();
    m_titleLayer->init(1,
                       imageFolder,
                       this,
                       10); // group 1, device folder, owner=this task, order 10

    AudioManager *audio = [AudioManager sharedManager];
    NSString *sePath = [NSBundle.mainBundle pathForResource:@"v10" ofType:@"m4a"];
    m_titleSe = (int)[audio loadSe:sePath isLoop:NO callName:nil group:1];
    NSString *bgmPath = [NSBundle.mainBundle pathForResource:@"bgm00_title" ofType:@"m4a"];
    [audio loadBgm:bgmPath isLoop:YES];
    [audio setBgmVolume:[UserSettingData bgmVolume]];
}

/**
 * Ghidra: TitleTask_finish (FUN_0002c3d0) — release SE/BGM/label + title view,
 * unload the title scene, reload character data, kill this task, and spawn the
 * main-menu task.
 * @complete
 */
void TitleTask::finish() {
    [[AudioManager sharedManager] releaseSe:0 resourceId:m_titleSe];
    if (m_titleLayer != nullptr) {
        delete m_titleLayer; // AepLyrCtrl_unlink + the deleting destructor
        m_titleLayer = nullptr;
    }
    m_aep->releaseAepTexture(1);
    if (m_versionLabel != nil) {
        m_versionLabel = nil;
    }
    gCharaManager.reload(); // CharaManager::reload
    kill();                 // +0x24 = 1

    if (C_TASK *menu = MenuCreateTask()) {
        menu->setPriority(3);
    }
    m_soundTestHidden = true; // +0x45 = 1: stop drawing the label after the handoff
}

// State-3 UI: a "conversion" button faded in over the title, plus (if a convert
// code is stored) an alert showing the player id + code.
void TitleTask::buildConversionButton() {
    MainViewController *root = RootVC();
    UIImage *img = [UIImage imageNamed:@"bt_conversion"];
    CGRect vf = root.view.frame;
    CGSize sz = img.size;
    CGRect frame = CGRectMake(vf.size.width - sz.width - 10.0f, -10.0f, sz.width, sz.height);
    m_conversionButton = [[CustomButton alloc] initWithFrame:frame];
    [m_conversionButton setTappableInsets:UIEdgeInsetsMake(-20, -20, -20, -20)];
    m_conversionButton.exclusiveTouch = YES;
    [m_conversionButton setBackgroundImage:img forState:UIControlStateNormal];
    [m_conversionButton addTarget:root
                           action:@selector(GotoInConversionPass)
                 forControlEvents:UIControlEventTouchUpInside];
    [root.view addSubview:m_conversionButton];
    m_conversionButton.alpha = 0;
    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                       this->m_conversionButton.alpha = 1;
                     }
                     completion:nil];

    NSString *code = [UserSettingData convertCode];
    if (code != nil) {
        NSString *msg = [NSString stringWithFormat:@"%@\n%@", [UserSettingData playerId], code];
        // Localized title + dismiss-button strings kept external (@""
        // placeholders); the alert reports back to the root VC (delegate).
        CommonAlertView *alert = [[CommonAlertView alloc]
                initWithTitle:@""
                      message:msg
                     delegate:(id<CommonAlertViewDelegate>)root
            cancelButtonTitle:nil
            otherButtonTitles:@""]; // root (MainViewController) conforms privately
                                    // (its .mm extension)
        alert.tag = 0;
        [alert show];
    }
    m_state3Built = true;
}

/**
 * Ghidra: TitleTask_update (FUN_0002b838) — the 10-state title / first-run
 * machine.
 * @complete
 */
void TitleTask::update(int /*deltaMs*/) {
    const bool tap = tapReleased();
    MainViewController *root = RootVC();
    DownloadMain *dl = [DownloadMain getInstance];

    switch (m_state) {
    case 0:
        setup();
        [[AudioManager sharedManager] playBgm:0.0f];
        m_aep->setAepTransitionMode(1); // fade in (fixed 30 frames)
        m_titleLayer->play();           // start the title animation
        m_state = 1;
        break;
    case 1:
        if (![UserSettingData isPolicyAccepted]) {
            m_state = 2; // must accept the policy first
            break;
        }
        m_state = 3; // straight to the title
        break;
    case 2: // wait for a tap, then go to the accept-policy screen
        if (tap) {
            neEngine::playSystemSe(1); // Ghidra: SysSePlayIntoSlot(sceneManager, 1)
            [root GotoAcceptPolicy];
            m_state = 1;
        }
        break;
    case 3:
        if (!m_state3Built) {
            buildConversionButton();
            break;
        }
        if (!tap) {
            break;
        }
        // Tapped through the title: start the DL file-list fetch (unless running),
        // show the "communicating" indicator, and advance.
        [[AudioManager sharedManager] playSe:0 resourceId:m_titleSe];
        if (![dl isGetDlFileListDownLoading]) {
            if (m_needUpdate) {
                [[DownloadMain getInstance] startGetDlFileListHttp:-1];
                [root InsertCommunicating];
            }
        } else {
            [root InsertCommunicating];
        }
        if (m_conversionButton != nil) {
            [UIView animateWithDuration:0.25
                                  delay:0
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                               this->m_conversionButton.alpha = 0;
                             }
                             completion:nil];
        }
        m_state = 4;
        break;
    case 4: // await the DL file list, then decide download vs skip
        if ([dl isGetDlFileListDownLoading]) {
            break;
        }
        [root DeleteCommunicating];
        m_dlFileList = [dl dlFileListDataArray];
        if (m_dlFileList == nil) {
            m_needUpdate = true;
            if ([UserSettingData lastCompletedClientVer] < AppDelegate.appDelegate.appVersionNum) {
                CommonAlertView *a = [[CommonAlertView alloc] initWithTitle:nil
                                                                    message:@""
                                                                   delegate:nil
                                                          cancelButtonTitle:nil
                                                          otherButtonTitles:@""];
                [a show];
                m_state = 3;
                break;
            }
        } else {
            m_needUpdate = false;
            if (m_dlFileList.count != 0) {
                m_state = 5;
                break;
            }
        }
        m_state = 7;
        break;
    case 5: // there are files to fetch: go to the default-download screen
        [root GotoDefaultDownload];
        m_state = 6;
        break;
    case 6: // default download finished
        if ([root isDefaultDlFailed] == 1) {
            m_needUpdate = true;
            m_state = 3;
        } else {
            [UserSettingData saveLastCompletedClientVer:AppDelegate.appDelegate.appVersionNum];
            m_state = 7;
        }
        break;
    case 7:
        m_aep->setAepTransitionMode(2); // fade out (fixed 30 frames)
        m_state = 8;
        break;
    case 8:
        if (m_aep->isTransitionDone()) {
            m_state = 9;
        }
        break;
    case 9:
        finish();
        break;
    default:
        break;
    }

    // Per-frame tail (Ghidra 0x2b838, run after every state including 9): advance
    // and draw the active AEP layers, then draw the version / sound-test label.
    updateAndDrawAepLayers(0); // Ghidra: FUN_0002c924
    drawSoundTestLabel();      // Ghidra: FUN_0002c52c
}

/**
 * TitleTask::drawSoundTestLabel — draw the version / sound-test label as an AEP
 * text command at (m_soundTestLabelX, 20), unless the label is suppressed. The
 * four numeric words are the per-corner gradient colour (20, 0, 100, 0x181818)
 * and the draw priority is 9.
 * @ghidraAddress 0x2c52c
 * @complete
 */
void TitleTask::drawSoundTestLabel() {
    if (m_soundTestHidden) {
        return;
    }
    m_aep->DrawText(m_versionLabel.UTF8String, m_soundTestLabelX, 20, 20, 0, 100, 0x181818, 9);
}
