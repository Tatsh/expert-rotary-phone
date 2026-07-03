//
//  TouchableTableView.h
//  pop'n rhythmin
//
//  A UITableView subclass that forwards began-touch events up the responder
//  chain so taps pass through to the content behind the table. Reconstructed
//  from Ghidra project rb420, program PopnRhythmin
//  (touchesBegan:withEvent: @ 0xe9750).
//

#import <UIKit/UIKit.h>

@interface TouchableTableView : UITableView

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
