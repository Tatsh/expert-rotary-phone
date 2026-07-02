//
//  AcViewerMusicCell.h
//  pop'n rhythmin
//
//  An arcade-viewer song row: four difficulty buttons (easy / normal / hyper / ex)
//  laid out horizontally, tagged 100..103 so the table can tell which was tapped.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:reuseIdentifier: @ 0x40430).
//

#import <UIKit/UIKit.h>

@interface AcViewerMusicCell : UITableViewCell

@property (nonatomic, retain) UIButton *easyBtn;    // tag 100 (acv_viewer_diff_ea)
@property (nonatomic, retain) UIButton *normalBtn;  // tag 101 (acv_viewer_diff_n)
@property (nonatomic, retain) UIButton *hyperBtn;   // tag 102 (acv_viewer_diff_h)
@property (nonatomic, retain) UIButton *exBtn;      // tag 103 (acv_viewer_diff_ex)

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
