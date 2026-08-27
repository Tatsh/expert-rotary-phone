//
//  StoreDetailViewController.h
//  pop'n rhythmin
//
//  The iPhone-side pack-detail screen: a pushed UIViewController (custom back
//  button in the nav bar) showing a StorePackInfo — a table of songs under a
//  StoreDetailHeaderView (jacket + name + price/buy button), with a loading
//  overlay and a dummy cover for in-flight work. The iPad counterpart is the
//  embedded StorePackDetailViewPad.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (init @
//  0x6f8c0, loadView @ 0x6fa3c, setPackInfo: @ 0x72d1c, setDelegate: @ 0x72d3c;
//  built by StoreMainViewController -showDetailViewForPhone: @ 0x4934c).
//

#import <UIKit/UIKit.h>

@class StorePackInfo;
@class StoreDetailViewController;
@class StoreDetailHeaderView;

/**
 * @brief Receives the phone detail screen's purchase, re-download and close requests.
 */
@protocol StoreDetailViewControllerDelegate <NSObject>
@optional
/**
 * @brief Start the StoreKit purchase; the buy button's not-owned path.
 * @param packInfo The pack to purchase.
 */
- (void)detailViewStartPurchase:(StorePackInfo *)packInfo;
/**
 * @brief Re-download an already-owned pack's songs; the buy button's owned-but-missing path.
 * @param packInfo The pack to re-download.
 */
- (void)reDownloadPackMusics:(StorePackInfo *)packInfo;
/**
 * @brief The detail screen dismissed an alert and should be closed.
 */
- (void)detailViewClose;
@end

/**
 * @brief The phone pack detail screen: the header card over the pack's song list.
 */
// Doxygen mis-parses an @interface whose line is wrapped before the ':' when an ivar block
// follows: it reports every protocol after the first as an undocumented ivar. Breaking inside the
// protocol list instead parses correctly, so the formatter is held off here.
// clang-format off
@interface StoreDetailViewController : UIViewController <UITableViewDataSource,
                                                         UITableViewDelegate> {
    StorePackInfo *packInfo; /**< The displayed pack; the synthesised setter is @ 0x72d1c. */
    __weak id<StoreDetailViewControllerDelegate> delegate; /**< The store main view controller. */
    NSArray *recommendPackIdArr;  /**< The cached recommended-pack ids, from MusicManager. */
    UITableView *m_PackTableView; /**< The song list. */
    /** The table header: the jacket, name and buy button. */
    StoreDetailHeaderView *m_HeaderView;
    UILabel *m_AccessingLabel; /**< The "読み込み中..." caption shown while the detail loads. */
    UIActivityIndicatorView *m_AccessingIndicator; /**< The spinner over the accessing label. */
    UIImage *packBgImage0; /**< The stretchable store_pack_bg_0 for even rows. */
    UIImage *packBgImage1; /**< The stretchable store_pack_bg_1 for odd rows. */
    NSMutableDictionary *artworkDownloaders; /**< The in-flight per-row jacket downloads. */
    /** The transparent cover host shown during purchase work. */
    UIViewController *dummyView;
    int rowSamplePlayed;          /**< The row index currently sampling, or -1. */
    id m_StorePackInfoDownloader; /**< The in-flight StorePackInfoDownloader. */
    id sampleDownloader;          /**< The in-flight preview-clip Downloader. */
    /** The BirthDayViewController age-gate modal, retained while shown. */
    id m_BirthDayView;
    /** The in-flight "register recommended pack" POST Downloader. */
    id recommendDownloader;
    BOOL isDownloadingSample; /**< The sampling row's clip is still buffering. */
}
// clang-format on

/** The displayed pack. */
@property(nonatomic, retain) StorePackInfo *packInfo;
/** The purchase, re-download and close delegate. */
@property(nonatomic, weak) id<StoreDetailViewControllerDelegate> delegate;

/**
 * @brief Build the view tree: the song table, the header view, the loading overlay, the
 * stretchable row backgrounds, the artwork-downloader map and the dummy cover.
 * @ghidraAddress 0x6fa3c
 */
- (void)loadView;

/**
 * @brief The nav-bar back button: pop this detail screen.
 */
- (void)backButtonFunc;

/**
 * @brief The header's buy button was tapped: hand the purchase to the delegate.
 * @param sender The tapped button.
 */
- (void)onPurchaseButton:(id)sender;

/**
 * @brief Kick off the detail load: show immediately when the songs are already present, otherwise
 * fetch them via a StorePackInfoDownloader.
 * @ghidraAddress 0x7048c
 */
- (void)loadInfo;

/**
 * @brief The detail arrived: size and fill the header, refresh the buy button, install the header
 * on the table, start the jacket download, then reveal and reload the table.
 * @ghidraAddress 0x702bc
 */
- (void)showPackInfo;

/**
 * @brief Stop the preview clip: fade the BGM, cancel and drop the sample download, then reload.
 * @ghidraAddress 0x70550
 */
- (void)stopSample;

/**
 * @brief The preview clip finished: stop the sampling row's cell and clear the sampling index.
 * @param sender The player that finished.
 * @ghidraAddress 0x70600
 */
- (void)finishBgm:(id)sender;

/**
 * @brief The not-owned purchase path: hand the pack to the delegate's StoreKit purchase.
 * @ghidraAddress 0x70af4
 */
- (void)doPurchase;

/**
 * @brief Whether the pack has songs and all of them are downloaded; the buy button uses it to
 * offer a re-download instead of a purchase.
 * @return YES when the pack is fully installed.
 * @ghidraAddress 0x70b9c
 */
- (BOOL)allDownloaded;

/**
 * @brief Whether this pack's id is in the recommended-pack list, which is fetched and cached
 * lazily.
 * @return YES when the pack is recommended.
 * @ghidraAddress 0x70c14
 */
- (BOOL)isRecommended;

/**
 * @brief Enable or disable the buy button for the ownership state.
 * @param owned YES to disable the button, because the pack is already owned.
 * @ghidraAddress 0x70b54
 */
- (void)setPurchaseState:(BOOL)owned;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
