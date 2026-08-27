//
//  AcViewerMusicViewController.h
//  pop'n rhythmin
//
//  The arcade (AC) viewer's song list: a transparent, separator-less
//  UITableView whose rows are AcViewerMusicCells (four difficulty buttons
//  each). A custom header shows the genre-category banner of the first listed
//  song; the right nav-bar button toggles the list between song-name and
//  genre-name ordering. Tapping a difficulty button seeds the AC-viewer's
//  current selection (music id / difficulty) and pushes the per-song option
//  screen.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithData:
//  @ 0xcba44, the table data source / delegate, the change / back /
//  difficulty-button actions and the DownloadMain visitor cleanup in dealloc).
//

#import <UIKit/UIKit.h>

// The AcViewerViewControllerDelegate protocol (the host that hides the split
// panel) is declared here; the iPad flow forwards this screen's delegate to the
// option screen.
#import "AcViewerOptionViewController.h"

@class AcMusicData;

/**
 * @brief The arcade viewer's song list.
 */
@interface AcViewerMusicViewController : UITableViewController

/** The host that hides the split panel. The binary stores the pointer raw, with no retain. Getter
 * @ 0xcca24, setter @ 0xcca34. */
@property(nonatomic, assign) id<AcViewerViewControllerDelegate> delegate;

/**
 * @brief Build the list from an array of arcade songs.
 *
 * The rows are sorted by song name or genre name per UserSettingData.isAcvGenreName, and the
 * header banner is keyed to the first song's genre category.
 * @param acMusicDataArray The songs to list, or nil for the full MusicManager arcade array.
 * @return The initialised controller.
 * @ghidraAddress 0xcba44
 */
- (instancetype)initWithData:(NSArray *)acMusicDataArray;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
