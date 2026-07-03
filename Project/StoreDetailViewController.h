//
//  StoreDetailViewController.h
//  pop'n rhythmin
//
//  The iPhone-side pack-detail screen: a pushed UIViewController (custom back button in the
//  nav bar) showing a StorePackInfo — a table of songs under a StoreDetailHeaderView (jacket +
//  name + price/buy button), with a loading overlay and a dummy cover for in-flight work. The
//  iPad counterpart is the embedded StorePackDetailViewPad.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (init @ 0x6f8c0, loadView @
//  0x6fa3c, setPackInfo: @ 0x72d1c, setDelegate: @ 0x72d3c; built by
//  StoreMainViewController -showDetailViewForPhone: @ 0x4934c).
//

#import <UIKit/UIKit.h>

@class StorePackInfo;
@class StoreDetailViewController;
@class StoreDetailHeaderView;

@protocol StoreDetailViewControllerDelegate <NSObject>
@optional
// Start the StoreKit purchase for `packInfo` (buy button, not-owned path). Ghidra selector
// detailViewStartPurchase:.
- (void)detailViewStartPurchase:(StorePackInfo *)packInfo;
// Re-download an already-owned pack's songs (buy button, owned-but-missing path). Ghidra
// selector reDownloadPackMusics:.
- (void)reDownloadPackMusics:(StorePackInfo *)packInfo;
// The detail screen dismissed an alert and should be closed. Ghidra selector detailViewClose.
- (void)detailViewClose;
@end

@interface StoreDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
    StorePackInfo *packInfo;                 // the displayed pack (synthesized setter @ 0x72d1c)
    __weak id<StoreDetailViewControllerDelegate> delegate;   // the store main VC
    NSArray *recommendPackIdArr;             // cached recommended-pack ids (from MusicManager)
    UITableView *m_PackTableView;            // the song list
    StoreDetailHeaderView *m_HeaderView;     // table header: jacket + name + buy button
    UILabel *m_AccessingLabel;               // "読み込み中..." while the detail loads
    UIActivityIndicatorView *m_AccessingIndicator;  // spinner over the accessing label
    UIImage *packBgImage0;                   // store_pack_bg_0 (stretchable) for even rows
    UIImage *packBgImage1;                   // store_pack_bg_1 (stretchable) for odd rows
    NSMutableDictionary *artworkDownloaders; // in-flight per-row jacket downloads
    UIViewController *dummyView;             // transparent cover host shown during purchase work
    int rowSamplePlayed;                     // row index currently sampling, or -1
    id m_StorePackInfoDownloader;            // in-flight pack-detail fetch (StorePackInfoDownloader)
    id sampleDownloader;                     // in-flight preview clip (Downloader)
    id m_BirthDayView;                       // age-gate modal (BirthDayViewController), retained while shown
    id recommendDownloader;                  // in-flight "register recommended pack" POST (Downloader)
    BOOL isDownloadingSample;                // the sampling row's clip is still buffering
}

@property (nonatomic, retain) StorePackInfo *packInfo;
@property (nonatomic, weak) id<StoreDetailViewControllerDelegate> delegate;

// Build the view tree: the song table, the StoreDetailHeaderView, the loading overlay, the
// stretchable row backgrounds, the artwork-downloader map and the dummy cover. Ghidra: loadView
// @ 0x6fa3c.
- (void)loadView;

// The nav-bar back button: pop this detail screen. Ghidra: selector backButtonFunc.
- (void)backButtonFunc;

// The header's buy button was tapped: hand the purchase to the delegate. Ghidra: selector
// onPurchaseButton:.
- (void)onPurchaseButton:(id)sender;

// Kick off the detail load: show immediately if the songs are already present, else fetch them
// via a StorePackInfoDownloader. Ghidra: loadInfo @ 0x7048c.
- (void)loadInfo;

// Detail arrived: size + fill the header, refresh the buy button, install it as the table
// header, start the jacket download, and reveal + reload the table. Ghidra: showPackInfo @ 0x702bc.
- (void)showPackInfo;

// Stop the preview clip: fade the BGM, cancel + drop the sample download, and reload. Ghidra:
// stopSample @ 0x70550.
- (void)stopSample;

// The preview clip finished: stop the sampling row's cell and clear the sampling index. Ghidra:
// finishBgm: @ 0x70600.
- (void)finishBgm:(id)sender;

// Not-owned purchase: hand the pack to the delegate's StoreKit purchase. Ghidra: doPurchase @
// 0x70af4.
- (void)doPurchase;

// YES if the pack has songs and they are all downloaded (used by the buy button to offer a
// re-download instead of a purchase). Ghidra: allDownloaded @ 0x70b9c.
- (BOOL)allDownloaded;

// YES if this pack's id is in the recommended-pack list (fetched + cached lazily). Ghidra:
// isRecommended @ 0x70c14.
- (BOOL)isRecommended;

// Enable/disable the buy button for the owned state (owned -> disabled). Ghidra:
// setPurchaseState: @ 0x70b54.
- (void)setPurchaseState:(BOOL)owned;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
