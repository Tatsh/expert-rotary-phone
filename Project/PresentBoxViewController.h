//
//  PresentBoxViewController.h
//  pop'n rhythmin
//
//  The "present box" (gift inbox) modal: a UITableViewController that lists the
//  player's pending server presents (one PresentBoxCell per row), plus an
//  "acquire all" button and an empty-state banner. It is raised over the main
//  menu inside its own UINavigationController (see -initAtNavigationController)
//  and slides itself in and out with a fade (phone) / frame-slide (pad)
//  open/close animation. Presents are fetched and claimed through the
//  DownloadMain singleton (this controller registers itself as its present-list
//  / present-claim delegate), and each claim is confirmed through a
//  CustomAlertView.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    initWithStyle:                       @ 0x24098
//    initAtNavigationController           @ 0x24938
//    dealloc                              @ 0x24988
//    viewDidLoad                          @ 0x24abc
//    viewWillAppear:                      @ 0x24ba4
//    didReceiveMemoryWarning              @ 0x24c6c
//    startOpenAnimation                   @ 0x24c98
//    endOpenAnimation                     @ 0x2514c
//    startCloseAnimation                  @ 0x25160
//    endCloseAnimation                    @ 0x255bc
//    numberOfSectionsInTableView:         @ 0x25628
//    tableView:numberOfRowsInSection:     @ 0x2562c
//    tableView:cellForRowAtIndexPath:     @ 0x25668
//    downloadMainFinished:                @ 0x257a8
//    backButtonFunc                       @ 0x25cdc
//    allGetFunc                           @ 0x25d48
//    indexPathForControlEvent:            @ 0x25db4
//    touchedGetButton:event:              @ 0x25e34
//    customAlertView:clickedButtonAtIndex: @ 0x260a4
//    isAnimationing                       @ 0x26144
//

#import <UIKit/UIKit.h>

#import "CustomAlertView.h" // CustomAlertViewDelegate

@interface PresentBoxViewController : UITableViewController <CustomAlertViewDelegate>

// Build the controller, wrap it in a fresh UINavigationController (portrait
// style) and return that host (the value the menu pushes into the scene).
// Ghidra: @ 0x24938.
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

// Slide / fade the box in and out. The host (MainViewController) drives these
// when showing / dismissing the present box and polls -isAnimationing to gate
// input while a transition is running. Ghidra: @ 0x24c98 / @ 0x25160.
- (void)startOpenAnimation;
- (void)startCloseAnimation;

// YES while an open/close animation is in flight (atomic read). Ghidra: @
// 0x26144.
- (BOOL)isAnimationing;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
