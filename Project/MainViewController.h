//
//  MainViewController.h
//  pop'n rhythmin
//
//  The root view controller and the bridge between UIKit and the C++ engine:
//  it hosts the GL view + AepManager scene and drives the render loop via a
//  CADisplayLink. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin.
//

#import <UIKit/UIKit.h>

@class neGLView;

@interface MainViewController : UIViewController

// Loop control (driven from AppDelegate lifecycle callbacks).
- (void)SetLoopInterval:(int)interval; // @ 0xc054
- (void)StartLoop;                     // @ 0xbeb0
- (void)PauseLoop;                     // @ 0xbef0
- (void)ResumeLoop;                    // @ 0xbf10
- (void)CreateTimer;                   // @ 0xbf30
- (void)RemoveTimer;                   // @ 0xc024
- (void)StopLoop;                      // @ 0xbed0 — stop for good (clear loop flag + drop timer)

// The hosted GL surface (the C++ scene renders into it).
- (neGLView *)GetGlView; // @ 0xc150

// One frame: advance tasks then render. Called by the CADisplayLink.
- (void)mainLoop; // @ 0xbe80
- (void)task;     // @ 0xbb5c
- (void)draw;     // @ 0xbd30

- (BOOL)isPause; // @ 0xf148
- (BOOL)isLoop;  // @ 0xf160

// Screen navigation. Each Goto* presents a modal child view controller over the
// GL view (with its open animation) and pauses the render loop; the matching
// *EndCallBack tears it down and resumes. This is the app's nav host that the
// title/menu tasks drive via neSceneManager::rootViewController.
- (void)GotoAcceptPolicy;                      // @ 0xda40
- (void)GotoSetting;                           // @ 0xc160
- (void)GotoMapSelect;                         // @ 0xc7d8
- (void)GotoFriendManage;                      // @ 0xcdc8
- (void)GotoDefaultDownload;                   // @ 0xd560
- (void)GotoInConversionPass;                  // @ 0xe53c
- (void)GotoPopnLink;                          // @ 0xd074
- (void)GotoInPlayerName;                      // @ 0xd248
- (void)GotoInviteCode;                        // @ 0xd7f4
- (void)GotoArcadeSearch;                      // @ 0xd930
- (void)GotoFriendScore:(unsigned int)musicId; // @ 0xcf9c
- (void)GotoReviewPage;                        // @ 0xe830
- (void)GotoRecommend:(void *)context;         // @ 0xc374
- (void)GotoSortSelect:(void *)context;        // @ 0xc9dc
- (void)GotoOverScoreLog:(void *)context;      // @ 0xe170
- (void)GotoPresentBox;                        // @ 0xdd8c
- (void)GotoStoreButton;                       // @ 0xd3d4
- (void)GotoAcViewer;                          // @ 0xdb24
- (void)GotoMailWithText:(NSString *)body;     // @ 0xe890

// Modal teardowns (invoked by each screen when it closes): release the
// controller and resume the render loop.
- (void)AcceptPolicyEndCallBack;     // @ 0xdae4
- (void)SettingEndCallBack;          // @ 0xc300
- (void)MapSelectEndCallBack;        // @ 0xc978
- (void)FriendManageEndCallBack;     // @ 0xcf0c
- (void)DefaultDownloadEndCallBack;  // @ 0xd640
- (void)InConversionPassEndCallBack; // @ 0xe67c
- (void)PopnLinkEndCallBack;         // @ 0xd1b8
- (void)InPlayerNameEndCallBack;     // @ 0xd370
- (void)InviteCodeEndCallBack;       // @ 0xd8d8
- (void)ArcadeSearchEndCallBack;     // @ 0xd9e8
- (void)FriendScoreEndCallBack;      // @ 0xd044
- (void)RecommendEndCallBack;        // @ 0xc754
- (void)SortSelectEndCallBack;       // @ 0xcd44
- (void)OverScoreLogEndCallBack;     // @ 0xe4b8
- (void)PresentBoxEndCallBack;       // @ 0xe0d4
- (void)StoreEndCallBack;            // @ 0xd518
- (void)AcViewerEndCallBack;         // @ 0xdcd4

// Synthesized state flags (atomic in the binary). Some are written internally
// via the backing ivar directly (readonly here); the read/write ones expose an
// atomic setter.
@property(atomic, readonly) BOOL settingViewing;   // @ 0xf0d0 — a settings modal is up
@property(atomic, readonly) BOOL cameraRollSaving; // @ 0xf0e8 — a camera-roll save is in flight
@property(atomic, readonly)
    BOOL isDefaultDlFailed;               // @ 0xf100 — the initial download failed (read by
                                          // TitleTask)
@property(atomic) BOOL rewardListViweing; // getter @ 0xf118, setter @ 0xf130 (name typo is real)
@property(atomic) BOOL isGotoTitle;       // getter @ 0xf178, setter @ 0xf190
@property(atomic) BOOL acMusicSelViewing; // getter @ 0xf1a8, setter @ 0xf1c0
@property(nonatomic, readonly) NSError *cameraRollError; // @ 0xf1d8 — last camera-roll save error

// The GL view's last captured frame, kept behind a modal so the render loop can
// pause; the result screen reads it (to know the backdrop is ready) then
// releases it once its own scene is up. Ghidra: getCapturedImage @ 0xbbac,
// releaseCapturedImage @ 0xbbbc.
- (UIImage *)getCapturedImage;
- (void)releaseCapturedImage;

// Capture the GL view's current frame into the backing store getCapturedImage
// reads. The result screen's per-frame draw fires this once, on the last frame
// of its intro effect, so the backdrop is frozen before the modal goes up.
// Ghidra: the "screenshot" selector (PTR_s_screenshot_0015a8fc) sent from
// FUN_0003f5f0.
- (void)screenshot;

// Snapshot the GL view's current renderbuffer into an upright UIImage (used by
// -draw when a screenshot has been armed).
+ (UIImage *)capture:(neGLView *)glView; // @ 0xbbec

// Show / hide the "communicating..." overlay while a network save is in flight
// (the result screen raises it around the score upload). Ghidra:
// InsertCommunicating @ 0xd6a8, DeleteCommunicating @ 0xd744.
- (void)InsertCommunicating;
- (void)DeleteCommunicating;
- (BOOL)IsCommunicatingEnable;       // @ 0xd790 — the overlay is present
- (BOOL)IsCommunicatingAnimationing; // @ 0xd764 — the overlay is mid-fade
- (void)CommunicatingFailed;         // @ 0xd7a8 — switch to the "failed" caption
- (void)CommunicatingEndCallBack;    // @ 0xd7c8 — the overlay finished closing;
                                     // drop it

// Feature-button gates the menu task reads before opening a screen: YES while
// the matching modal is already up.
- (BOOL)IsFriendManageEnable; // @ 0xcf70
- (BOOL)IsPopnLinkEnable;     // @ 0xd21c
- (BOOL)IsStoreEnable;        // @ 0xd548
- (BOOL)IsInviteCodeEnable;   // @ 0xd918
- (BOOL)IsArcadeSearchEnable; // @ 0xda28
- (BOOL)IsPresentBoxEnable;   // @ 0xe158

// Save a captured screenshot (stored under the app-support dir as `fileName`)
// into the camera roll; cameraRollSaving is YES until the async save completes.
- (void)SaveToCameraRoll:(NSString *)fileName; // @ 0xe704

// Install a one-shot C confirm callback fired by the common/custom alert
// delegates.
- (void)SetAlertViewCallback:(void (*)(void *))callback param:(void *)param; // @ 0xe810

// The fade-to-black scrim over the whole view (used on scene transitions).
- (void)InsertBlackBoard;  // @ 0xeca4 — snap on, opaque, on top
- (void)FadeInBlackBoard;  // @ 0xede8 — fade in over 0.3s
- (void)FadeOutBlackBoard; // @ 0xefdc — fade out over 0.5s

// Reward app-list (offer wall) delegate callbacks; rewardListViweing tracks
// visibility.
- (void)appListDidAppear;                          // @ 0xeaec
- (void)appListDidDisappear;                       // @ 0xeaf0
- (void)appListFailLoadWithError:(NSError *)error; // @ 0xeb1c

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
