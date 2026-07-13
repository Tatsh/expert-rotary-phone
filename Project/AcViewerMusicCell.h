//
//  AcViewerMusicCell.h
//  pop'n rhythmin
//
//  An arcade-viewer song row: four difficulty buttons (easy / normal / hyper /
//  ex) laid out horizontally, tagged 100..103 so the table can tell which was
//  tapped. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:reuseIdentifier: @ 0x40430).
//

#import <UIKit/UIKit.h>

@class AcMusicData;

@interface AcViewerMusicCell : UITableViewCell

// atomic retain (the binary getters read the ivar behind a DataMemoryBarrier;
// the buttons are released in -dealloc). Getter addresses annotated.
@property(atomic, retain) UIButton *easyBtn;   // tag 100 (acv_viewer_diff_ea); getter @ 0x4168c
@property(atomic, retain) UIButton *normalBtn; // tag 101 (acv_viewer_diff_n);  getter @ 0x416a0
@property(atomic, retain) UIButton *hyperBtn;  // tag 102 (acv_viewer_diff_h);  getter @ 0x416b4
@property(atomic, retain) UIButton *exBtn;     // tag 103 (acv_viewer_diff_ex);  getter @ 0x416c8

// Bind the row to one arcade song: banner background, song/genre title, and the
// level number for each available difficulty (drawn inside its difficulty
// button). Ghidra: setData: @ 0x409e0.
- (void)setData:(AcMusicData *)data;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
