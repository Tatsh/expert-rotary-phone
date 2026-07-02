//
//  MainViewController.h
//  pop'n rhythmin
//
//  The root view controller and the bridge between UIKit and the C++ engine:
//  it hosts the GL view + AepManager scene and drives the render loop via a
//  CADisplayLink. Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import <UIKit/UIKit.h>

@class neGLView;

@interface MainViewController : UIViewController

// Loop control (driven from AppDelegate lifecycle callbacks).
- (void)SetLoopInterval:(int)interval;  // @ 0xc054
- (void)StartLoop;                      // @ 0xbeb0
- (void)PauseLoop;                      // @ 0xbef0
- (void)ResumeLoop;                     // @ 0xbf10
- (void)CreateTimer;                    // @ 0xbf30
- (void)RemoveTimer;                    // @ 0xc024

// One frame: advance tasks then render. Called by the CADisplayLink.
- (void)mainLoop;                       // @ 0xbe80
- (void)task;                           // @ 0xbb5c
- (void)draw;                           // @ 0xbd30

- (BOOL)isPause;                        // @ 0xf148
- (BOOL)isLoop;                         // @ 0xf160

// Screen navigation. Each Goto* presents a modal child view controller over the GL
// view (with its open animation) and pauses the render loop; the matching
// *EndCallBack tears it down and resumes. This is the app's nav host that the
// title/menu tasks drive via neSceneManager::rootViewController.
- (void)GotoAcceptPolicy;               // @ 0xda40
- (void)GotoSetting;                    // @ 0xc160
- (void)GotoMapSelect;                  // @ 0xc7d8
- (void)GotoFriendManage;               // @ 0xcdc8
- (void)GotoDefaultDownload;            // @ 0xd560
- (void)GotoInConversionPass;           // @ 0xe53c

// Modal teardowns (invoked by each screen when it closes): release the controller
// and resume the render loop.
- (void)AcceptPolicyEndCallBack;        // @ 0xdae4
- (void)SettingEndCallBack;             // @ 0xc300
- (void)MapSelectEndCallBack;           // @ 0xc978
- (void)FriendManageEndCallBack;        // @ 0xcf0c
- (void)DefaultDownloadEndCallBack;     // @ 0xd640
- (void)InConversionPassEndCallBack;    // @ 0xe67c

// Whether the initial default download reported failure (read by TitleTask).
- (BOOL)isDefaultDlFailed;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
