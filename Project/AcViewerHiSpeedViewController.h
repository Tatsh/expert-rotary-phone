//
//  AcViewerHiSpeedViewController.h
//  pop'n rhythmin
//
//  The arcade (AC) viewer's HI-SPEED option list: a UITableView of eleven
//  values (OFF, HI-SP 1.5 .. HI-SP 6.0). Pushed by AcViewerOptionViewController
//  when the HI-SPEED row is tapped; selecting a value stores it into
//  UserSettingData (saveAcvHiSpeed:) and pops back to the option list.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (init @
//  0x2cbb0, viewDidLoad @ 0x2d484, handleGesture: @ 0x2d4b4, the table data
//  source / delegate, and touchedBackButton: @ 0x2d738).
//

#import <UIKit/UIKit.h>

@interface AcViewerHiSpeedViewController : UITableViewController
@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
