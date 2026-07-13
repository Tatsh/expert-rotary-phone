//
//  AcViewerSplitViewController.h
//  pop'n rhythmin
//
//  The iPad layout of the arcade (AC) viewer: a floating split panel over a
//  dimmed backdrop — a left column of category/music-name/genre buttons and a
//  right navigation pane that hosts the AcViewerCategoryViewController list.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (init @
//  0x318e8, initForLeftView
//  @ 0x322c4, the shared open/close fade animations,
//  onButtonTouched:/onBackButtonTouched:).
//
//  All the app's modal view controllers share this animation lifecycle:
//    startOpenAnimation  — fade the view (+ its nav controller view) 0 -> 1;
//                          didStop -> endOpenAnimation (clears isAnimationing)
//    startCloseAnimation — fade 1 -> 0; didStop -> endCloseAnimation
//    endCloseAnimation   — removeFromSuperview + [rootVC <Screen>EndCallBack]
//  (iPad variants sometimes slide/фade a "black board" instead; guarded by an
//  isAnimationing flag so a transition never overlaps.)
//

#import <UIKit/UIKit.h>

@interface AcViewerSplitViewController : UIViewController

- (void)startOpenAnimation;  // @ 0x3272c
- (void)startCloseAnimation; // @ 0x32870

// Fade the panel out (or, non-animated, after a short delay) and swap the right
// pane to the AcViewer option screen. Ghidra: startHiddenAnimation: @ 0x32a80.
- (void)startHiddenAnimation:(BOOL)animated;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
