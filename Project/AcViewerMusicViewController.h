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

@interface AcViewerMusicViewController : UITableViewController

// Synthesized accessors: delegate getter @ 0xcca24, setDelegate: @ 0xcca34
// (assign — the binary stores the pointer raw, with no retain).
// @ 0xcca24
// @ 0xcca34
@property(nonatomic, assign) id<AcViewerViewControllerDelegate> delegate;

// Build the list from an array of AcMusicData (nil -> the full MusicManager AC
// array). The rows are sorted by song name or genre name per
// UserSettingData.isAcvGenreName, and the header banner is keyed to the first
// song's genre category. Ghidra: initWithData: @ 0xcba44.
- (instancetype)initWithData:(NSArray *)acMusicDataArray;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
