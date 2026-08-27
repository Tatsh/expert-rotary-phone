/** @file
 * The root view controller and the bridge between UIKit and the C++ engine: it hosts the GL view
 * and the AepManager scene, and drives the render loop via a CADisplayLink. Reconstructed from
 * Ghidra project rb420, program PopnRhythmin.
 */

#import <UIKit/UIKit.h>

@class neGLView;

/**
 * @brief The root view controller: the render-loop host and the app's modal navigation host.
 */
@interface MainViewController : UIViewController

// Loop control, driven from the AppDelegate lifecycle callbacks.

/**
 * @brief Set the CADisplayLink frame interval.
 * @param interval The frame interval.
 * @ghidraAddress 0xc054
 */
- (void)SetLoopInterval:(int)interval;
/**
 * @brief Start the render loop.
 * @ghidraAddress 0xbeb0
 */
- (void)StartLoop;
/**
 * @brief Pause the render loop, leaving the timer in place.
 * @ghidraAddress 0xbef0
 */
- (void)PauseLoop;
/**
 * @brief Resume a paused render loop.
 * @ghidraAddress 0xbf10
 */
- (void)ResumeLoop;
/**
 * @brief Create the CADisplayLink timer.
 * @ghidraAddress 0xbf30
 */
- (void)CreateTimer;
/**
 * @brief Invalidate and drop the CADisplayLink timer.
 * @ghidraAddress 0xc024
 */
- (void)RemoveTimer;
/**
 * @brief Stop the render loop for good: clear the loop flag and drop the timer.
 * @ghidraAddress 0xbed0
 */
- (void)StopLoop;

/**
 * @brief The hosted GL surface the C++ scene renders into.
 * @return The GL view.
 * @ghidraAddress 0xc150
 */
- (neGLView *)GetGlView;

/**
 * @brief One frame: advance the tasks, then render. The CADisplayLink calls it.
 * @ghidraAddress 0xbe80
 */
- (void)mainLoop;
/**
 * @brief Advance the engine's task list by one frame.
 * @ghidraAddress 0xbb5c
 */
- (void)task;
/**
 * @brief Render one frame, capturing a screenshot first when one has been armed.
 * @ghidraAddress 0xbd30
 */
- (void)draw;

/**
 * @brief Whether the render loop is paused.
 * @return YES while paused.
 * @ghidraAddress 0xf148
 */
- (BOOL)isPause;
/**
 * @brief Whether the render loop is running.
 * @return YES while looping.
 * @ghidraAddress 0xf160
 */
- (BOOL)isLoop;

// Screen navigation. Each Goto* presents a modal child view controller over the GL view, with its
// open animation, and pauses the render loop; the matching *EndCallBack tears it down and resumes.
// This is the app's navigation host that the title and menu tasks drive via
// neSceneManager::rootViewController.

/**
 * @brief Present the first-run terms-acceptance modal.
 * @ghidraAddress 0xda40
 */
- (void)GotoAcceptPolicy;
/**
 * @brief Present the settings screen.
 * @ghidraAddress 0xc160
 */
- (void)GotoSetting;
/**
 * @brief Present the sugoroku map-select screen.
 * @ghidraAddress 0xc7d8
 */
- (void)GotoMapSelect;
/**
 * @brief Present the friend-management hub.
 * @ghidraAddress 0xcdc8
 */
- (void)GotoFriendManage;
/**
 * @brief Present the launch-time default-data downloader.
 * @ghidraAddress 0xd560
 */
- (void)GotoDefaultDownload;
/**
 * @brief Present the device-change pass-entry screen.
 * @ghidraAddress 0xe53c
 */
- (void)GotoInConversionPass;
/**
 * @brief Present the pop'n-link top screen.
 * @ghidraAddress 0xd074
 */
- (void)GotoPopnLink;
/**
 * @brief Present the player-name entry screen.
 * @ghidraAddress 0xd248
 */
- (void)GotoInPlayerName;
/**
 * @brief Present the invite-code screen.
 * @ghidraAddress 0xd7f4
 */
- (void)GotoInviteCode;
/**
 * @brief Present the arcade-search screen.
 * @ghidraAddress 0xd930
 */
- (void)GotoArcadeSearch;
/**
 * @brief Present the friend-score screen for one song.
 * @param musicId The song to show scores for.
 * @ghidraAddress 0xcf9c
 */
- (void)GotoFriendScore:(unsigned int)musicId;
/**
 * @brief Open the App Store review page.
 * @ghidraAddress 0xe830
 */
- (void)GotoReviewPage;
/**
 * @brief Present the recommendations screen.
 * @param context The opaque caller context threaded back on close.
 * @ghidraAddress 0xc374
 */
- (void)GotoRecommend:(void *)context;
/**
 * @brief Present the sort-select modal.
 * @param context The opaque caller context threaded back on close.
 * @ghidraAddress 0xc9dc
 */
- (void)GotoSortSelect:(void *)context;
/**
 * @brief Present the over-score log.
 * @param context The opaque caller context threaded back on close.
 * @ghidraAddress 0xe170
 */
- (void)GotoOverScoreLog:(void *)context;
/**
 * @brief Present the present box.
 * @ghidraAddress 0xdd8c
 */
- (void)GotoPresentBox;
/**
 * @brief Present the store screen.
 * @ghidraAddress 0xd3d4
 */
- (void)GotoStoreButton;
/**
 * @brief Present the arcade viewer.
 * @ghidraAddress 0xdb24
 */
- (void)GotoAcViewer;
/**
 * @brief Present the mail composer with a pre-filled body.
 * @param body The message body.
 * @ghidraAddress 0xe890
 */
- (void)GotoMailWithText:(NSString *)body;

// Modal teardowns, invoked by each screen when it closes: they release the controller and resume
// the render loop.

/**
 * @brief The terms-acceptance modal closed.
 * @ghidraAddress 0xdae4
 */
- (void)AcceptPolicyEndCallBack;
/**
 * @brief The settings screen closed.
 * @ghidraAddress 0xc300
 */
- (void)SettingEndCallBack;
/**
 * @brief The map-select screen closed.
 * @ghidraAddress 0xc978
 */
- (void)MapSelectEndCallBack;
/**
 * @brief The friend-management hub closed.
 * @ghidraAddress 0xcf0c
 */
- (void)FriendManageEndCallBack;
/**
 * @brief The default-data downloader closed.
 * @ghidraAddress 0xd640
 */
- (void)DefaultDownloadEndCallBack;
/**
 * @brief The device-change pass-entry screen closed.
 * @ghidraAddress 0xe67c
 */
- (void)InConversionPassEndCallBack;
/**
 * @brief The pop'n-link top screen closed.
 * @ghidraAddress 0xd1b8
 */
- (void)PopnLinkEndCallBack;
/**
 * @brief The player-name entry screen closed.
 * @ghidraAddress 0xd370
 */
- (void)InPlayerNameEndCallBack;
/**
 * @brief The invite-code screen closed.
 * @ghidraAddress 0xd8d8
 */
- (void)InviteCodeEndCallBack;
/**
 * @brief The arcade-search screen closed.
 * @ghidraAddress 0xd9e8
 */
- (void)ArcadeSearchEndCallBack;
/**
 * @brief The friend-score screen closed.
 * @ghidraAddress 0xd044
 */
- (void)FriendScoreEndCallBack;
/**
 * @brief The recommendations screen closed.
 * @ghidraAddress 0xc754
 */
- (void)RecommendEndCallBack;
/**
 * @brief The sort-select modal closed.
 * @ghidraAddress 0xcd44
 */
- (void)SortSelectEndCallBack;
/**
 * @brief The over-score log closed.
 * @ghidraAddress 0xe4b8
 */
- (void)OverScoreLogEndCallBack;
/**
 * @brief The present box closed.
 * @ghidraAddress 0xe0d4
 */
- (void)PresentBoxEndCallBack;
/**
 * @brief The store screen closed.
 * @ghidraAddress 0xd518
 */
- (void)StoreEndCallBack;
/**
 * @brief The arcade viewer closed.
 * @ghidraAddress 0xdcd4
 */
- (void)AcViewerEndCallBack;

// Synthesized state flags, atomic in the binary. Some are written internally through the backing
// ivar directly and are readonly here; the read/write ones expose an atomic setter.

/** Whether a settings modal is up. Getter @ 0xf0d0. */
@property(atomic, readonly) BOOL settingViewing;
/** Whether a camera-roll save is in flight. Getter @ 0xf0e8. */
@property(atomic, readonly) BOOL cameraRollSaving;
/** Whether the initial download failed; TitleTask reads it. Getter @ 0xf100. */
@property(atomic, readonly) BOOL isDefaultDlFailed;
/** Whether the reward app list is on screen. The name's typo is in the binary. Getter @ 0xf118,
 * setter @ 0xf130. */
@property(atomic) BOOL rewardListViweing;
/** Whether the app is returning to the title screen. Getter @ 0xf178, setter @ 0xf190. */
@property(atomic) BOOL isGotoTitle;
/** Whether the arcade music-select screen is up. Getter @ 0xf1a8, setter @ 0xf1c0. */
@property(atomic) BOOL acMusicSelViewing;
/** The last camera-roll save error. Getter @ 0xf1d8. */
@property(nonatomic, readonly) NSError *cameraRollError;

/**
 * @brief The GL view's last captured frame, kept behind a modal so the render loop can pause.
 *
 * The result screen reads it to know the backdrop is ready, then releases it once its own scene is
 * up.
 * @return The captured frame, or nil when none is armed.
 * @ghidraAddress 0xbbac
 */
- (UIImage *)getCapturedImage;
/**
 * @brief Release the captured frame.
 * @ghidraAddress 0xbbbc
 */
- (void)releaseCapturedImage;

/**
 * @brief Capture the GL view's current frame into the backing store -getCapturedImage reads.
 *
 * The result screen's per-frame draw fires this once, on the last frame of its intro effect, so
 * the backdrop is frozen before the modal goes up. Ghidra: the "screenshot" selector
 * (PTR_s_screenshot_0015a8fc) sent from FUN_0003f5f0.
 */
- (void)screenshot;

/**
 * @brief Snapshot the GL view's current renderbuffer into an upright UIImage; -draw uses it when a
 * screenshot has been armed.
 * @param glView The view to snapshot.
 * @return The captured image.
 * @ghidraAddress 0xbbec
 */
+ (UIImage *)capture:(neGLView *)glView;

// Show and hide the "communicating…" overlay while a network save is in flight; the result screen
// raises it around the score upload.

/**
 * @brief Raise the "communicating…" overlay.
 * @ghidraAddress 0xd6a8
 */
- (void)InsertCommunicating;
/**
 * @brief Dismiss the "communicating…" overlay.
 * @ghidraAddress 0xd744
 */
- (void)DeleteCommunicating;
/**
 * @brief Whether the overlay is present.
 * @return YES while the overlay exists.
 * @ghidraAddress 0xd790
 */
- (BOOL)IsCommunicatingEnable;
/**
 * @brief Whether the overlay is mid-fade.
 * @return YES while a fade is running.
 * @ghidraAddress 0xd764
 */
- (BOOL)IsCommunicatingAnimationing;
/**
 * @brief Switch the overlay to its "failed" caption.
 * @ghidraAddress 0xd7a8
 */
- (void)CommunicatingFailed;
/**
 * @brief The overlay finished closing; drop it.
 * @ghidraAddress 0xd7c8
 */
- (void)CommunicatingEndCallBack;

// Feature-button gates the menu task reads before opening a screen: each is YES while the matching
// modal is already up.

/**
 * @brief Whether the friend-management hub is already up.
 * @return YES when the modal exists.
 * @ghidraAddress 0xcf70
 */
- (BOOL)IsFriendManageEnable;
/**
 * @brief Whether the pop'n-link screen is already up.
 * @return YES when the modal exists.
 * @ghidraAddress 0xd21c
 */
- (BOOL)IsPopnLinkEnable;
/**
 * @brief Whether the store screen is already up.
 * @return YES when the modal exists.
 * @ghidraAddress 0xd548
 */
- (BOOL)IsStoreEnable;
/**
 * @brief Whether the invite-code screen is already up.
 * @return YES when the modal exists.
 * @ghidraAddress 0xd918
 */
- (BOOL)IsInviteCodeEnable;
/**
 * @brief Whether the arcade-search screen is already up.
 * @return YES when the modal exists.
 * @ghidraAddress 0xda28
 */
- (BOOL)IsArcadeSearchEnable;
/**
 * @brief Whether the present box is already up.
 * @return YES when the modal exists.
 * @ghidraAddress 0xe158
 */
- (BOOL)IsPresentBoxEnable;

/**
 * @brief Save a captured screenshot into the camera roll; cameraRollSaving stays YES until the
 * async save completes.
 * @param fileName The file, stored under the Application Support directory.
 * @ghidraAddress 0xe704
 */
- (void)SaveToCameraRoll:(NSString *)fileName;

/**
 * @brief Install a one-shot C confirm callback fired by the common and custom alert delegates.
 * @param callback The function to call.
 * @param param The opaque parameter to pass it.
 * @ghidraAddress 0xe810
 */
- (void)SetAlertViewCallback:(void (*)(void *))callback param:(void *)param;

// The fade-to-black scrim over the whole view, used on scene transitions.

/**
 * @brief Snap the scrim on, opaque and on top.
 * @ghidraAddress 0xeca4
 */
- (void)InsertBlackBoard;
/**
 * @brief Fade the scrim in over 0.3 s.
 * @ghidraAddress 0xede8
 */
- (void)FadeInBlackBoard;
/**
 * @brief Fade the scrim out over 0.5 s.
 * @ghidraAddress 0xefdc
 */
- (void)FadeOutBlackBoard;

// Reward app-list (offer wall) delegate callbacks; rewardListViweing tracks visibility.

/**
 * @brief The reward app list appeared.
 * @ghidraAddress 0xeaec
 */
- (void)appListDidAppear;
/**
 * @brief The reward app list disappeared.
 * @ghidraAddress 0xeaf0
 */
- (void)appListDidDisappear;
/**
 * @brief The reward app list failed to load.
 * @param error What went wrong.
 * @ghidraAddress 0xeb1c
 */
- (void)appListFailLoadWithError:(NSError *)error;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
