//
//  AcViewerPopKunViewController.h
//  pop'n rhythmin
//
//  The arcade (AC) viewer's POP-KUN option list: a UITableView of two values
//  (OFF, BEAT POP). Pushed by AcViewerOptionViewController when the POP-KUN row
//  is tapped; selecting a value stores it into UserSettingData (saveAcvPopKun:)
//  and pops back to the option list.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (init @
//  0x7d01c, viewDidLoad @ 0x7d8f0, the table data source / delegate, and
//  touchedBackButton: @ 0x7db38).
//

#import <UIKit/UIKit.h>

@interface AcViewerPopKunViewController : UITableViewController
@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
