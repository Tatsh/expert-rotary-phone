//
//  AcViewerHidSudViewController.h
//  pop'n rhythmin
//
//  The arcade (AC) viewer's HID-SUD option list: a UITableView of four values
//  (OFF, HIDDEN, SUDDEN, HID-SUD). Pushed by AcViewerOptionViewController when
//  the HID-SUD row is tapped; selecting a value stores it into UserSettingData
//  (saveAcvHidSud:) and pops back to the option list.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (init @
//  0x1adf4, viewDidLoad @ 0x1b6c8, the table data source / delegate, and
//  touchedBackButton: @ 0x1b910).
//

#import <UIKit/UIKit.h>

@interface AcViewerHidSudViewController : UITableViewController
@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
