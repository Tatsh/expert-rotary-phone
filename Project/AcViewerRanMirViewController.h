//
//  AcViewerRanMirViewController.h
//  pop'n rhythmin
//
//  The arcade (AC) viewer's RAN-MIR option list: a UITableView of four values
//  (OFF, RANDOM, MIRROR, S-RAN). Pushed by AcViewerOptionViewController when
//  the RAN-MIR row is tapped; selecting a value stores it into UserSettingData
//  (saveAcvRanMir:) and pops back to the option list.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (init @
//  0xa6c20, viewDidLoad @ 0xa74f4, the table data source / delegate, and
//  touchedBackButton: @ 0xa7738).
//

#import <UIKit/UIKit.h>

@interface AcViewerRanMirViewController : UITableViewController
@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
