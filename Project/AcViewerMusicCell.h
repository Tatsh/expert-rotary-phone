/** @file
 * An arcade-viewer song row: four difficulty buttons (easy, normal, hyper and ex) laid out
 * horizontally, tagged 100..103 so the table can tell which was tapped. Reconstructed from Ghidra
 * project rb420, program PopnRhythmin (initWithStyle:reuseIdentifier: @ 0x40430).
 */

#import <UIKit/UIKit.h>

@class AcMusicData;

/**
 * @brief One arcade-viewer song row, carrying a button per difficulty.
 */
@interface AcViewerMusicCell : UITableViewCell

// The accessors are atomic retain: the binary getters read the ivar behind a DataMemoryBarrier and
// the buttons are released in -dealloc.

/** The Easy difficulty button, tag 100 (acv_viewer_diff_ea). Getter @ 0x4168c. */
@property(atomic, retain) UIButton *easyBtn;
/** The Normal difficulty button, tag 101 (acv_viewer_diff_n). Getter @ 0x416a0. */
@property(atomic, retain) UIButton *normalBtn;
/** The Hyper difficulty button, tag 102 (acv_viewer_diff_h). Getter @ 0x416b4. */
@property(atomic, retain) UIButton *hyperBtn;
/** The EX difficulty button, tag 103 (acv_viewer_diff_ex). Getter @ 0x416c8. */
@property(atomic, retain) UIButton *exBtn;

/**
 * @brief Bind the row to one arcade song: the banner background, the song or genre title, and the
 * level number for each available difficulty, drawn inside its difficulty button.
 * @param data The song to bind.
 * @ghidraAddress 0x409e0
 */
- (void)setData:(AcMusicData *)data;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
