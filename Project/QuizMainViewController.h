//
//  QuizMainViewController.h
//  pop'n rhythmin
//
//  The daily-quiz screen: a UITableViewController that shows one question on a
//  "blackboard" table header with a row per answer choice (QuizCell). The player taps a
//  row to answer; the reply is posted to the server, the pick is graded (○/✕ stamp +
//  SE), and a tap on the graded board reveals the running correct/incorrect/streak
//  totals. Every 5th correct answer grants a character ticket and pops a present window.
//  Questions and replies go through the Downloader (this controller is its delegate);
//  the running totals are persisted through UserSettingData.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    initWithStyle:                       @ 0xda198
//    dealloc                              @ 0xdb2a4
//    viewDidLoad                          @ 0xdb3d4
//    didReceiveMemoryWarning              @ 0xdb438
//    numberOfSectionsInTableView:         @ 0xdb464
//    tableView:numberOfRowsInSection:     @ 0xdb468
//    tableView:cellForRowAtIndexPath:     @ 0xdb538
//    tableView:titleForHeaderInSection:   @ 0xdb674
//    tableView:didSelectRowAtIndexPath:   @ 0xdb678
//    downloaderFinished:                  @ 0xdb730
//    downloaderProceed:                   @ 0xdb7ac
//    downloaderError:                     @ 0xdb7b0
//    touchedBackButton:                   @ 0xdb8cc
//    getQuizFinished                      @ 0xdb968
//    replyQuizFinished                    @ 0xdbda4
//    startGetQuizHttp                     @ 0xdc2b8
//    startReplyQuizHttp                   @ 0xdc36c
//    drawResult                           @ 0xdc4ec
//    touchesBegan:withEvent:              @ 0xdca68
//

#import <UIKit/UIKit.h>

#import "Downloader.h"   // DownloaderDelegate

@interface QuizMainViewController : UITableViewController <DownloaderDelegate>

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
