//
//  FreeRequestListViewController.h
//  pop'n rhythmin
//
//  The "free request" recommended-friend list. A grouped-style
//  UITableViewController showing a header plate ("fpl_text"), a spinning
//  activity indicator over a dimmed dummy overlay while the recommend-friend
//  list downloads, and one FreeRequestListCell per returned player. Tapping a
//  row raises a FreeRequestDetail overlay (the friend-request confirm screen).
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle: @ 0xe5430 and 13 more methods). Built in
//  FreeRequestListViewController.mm (Objective-C++: drives the C++
//  neSceneManager / neEngine singletons).
//

#import <UIKit/UIKit.h>

@interface FreeRequestListViewController : UITableViewController

// Grouped-style table: a "fpl_text" header plate, a dimmed dummy overlay
// carrying a centred activity indicator, and a custom back button in the nav
// item. Ghidra: @ 0xe5430.
- (instancetype)initWithStyle:(UITableViewStyle)style;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
