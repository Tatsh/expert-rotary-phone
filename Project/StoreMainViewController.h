//
//  StoreMainViewController.h
//  pop'n rhythmin
//
//  The store's main tab: browses the song-pack catalogue in a table, drives two
//  StorePackListControllers (the normal list and the recommend list), lazily
//  loads jacket artwork, and pushes pack-detail screens. This file is grown
//  incrementally from the decompilation; the constructor + the methods the host
//  calls land first, the table datasource / download callbacks / detail
//  navigation follow.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    initWithParent: @ 0x42b40   startStoreClose @ 0x4a2d8   isAlertViewShowing
//    @ 0x4a2ec packListDownloadSuccess: @ 0x449e0 (reconstructed alongside the
//    table methods)
//

#import <UIKit/UIKit.h>

#import "CommonAlertView.h"
#import "ImageDownloader.h"
#import "StoreDownloadManager.h"
#import "StorePackInfoDownloader.h"
#import "StorePackListController.h"
#import "StorePromotionView.h"

@class StoreViewController;
@class StorePackDetailViewPad;
@class StorePackInfo;

/**
 * @brief The store's main pack catalogue: the pack table, the promotion banner, and the purchase,
 * download and restore flows.
 */
@interface StoreMainViewController : UIViewController <StorePackListControllerDelegate,
                                                       StoreDownloadManagerDelegate,
                                                       StorePackInfoDownloaderDelegate,
                                                       ImageDownloaderDelegate,
                                                       StorePromotionViewDelegate,
                                                       CommonAlertViewDelegate,
                                                       UITableViewDataSource,
                                                       UITableViewDelegate,
                                                       UIScrollViewDelegate> {
    __weak StoreViewController *m_StoreViewCtrl;      /**< The owning tab host; not retained. */
    StorePackListController *m_PackListCtrl;          /**< The normal catalogue. */
    StorePackListController *m_RecommendPackListCtrl; /**< The recommend catalogue. */
    NSMutableDictionary *m_ArtworkDownloaders; /**< The jacket ImageDownloaders, keyed by index. */
    BOOL m_IsPad;                              /**< Whether this is the iPad layout. */
    int m_OffsetForOS;                         /**< The iOS 7 layout nudge; 46 on phone. */
    BOOL m_IsStoreClosing;                     /**< Set while the host fades out. */
    BOOL _isAlertViewShowing;                  /**< An alert is up; the flag is atomic. */

    // Pack-table "show more" controls, built by -viewDidLoad and driven by -selectShowMore.

    /** The "▼ SHOW MORE ▼" and "読み込み中..." button. */
    UIButton *m_ShowMoreButton;
    UIActivityIndicatorView *m_ShowMoreIndicator; /**< The spinner shown while fetching more. */
    BOOL m_IsLoadingMoreList;                     /**< A "load more packs" fetch is in flight. */

    StorePromotionView *m_PromotionView; /**< The promotion banner at the top of the pack table. */
    UIImageView *m_PromotionViewDummy;   /**< The promotion banner's background dummy. */
    UILabel *m_PackTableLabel;           /**< Shown once the first page arrives. */

    UIImage *m_PackBgImage0; /**< The even-row pack-cell backdrop, store_pack_bg_0. */
    UIImage *m_PackBgImage1; /**< The odd-row pack-cell backdrop, store_pack_bg_1. */

    /** The "復元" (restore) bar button, lazily added on the first successful page. */
    UIButton *m_RestoreButton;

    UIView *m_CoverViewPad; /**< The iPad-only dim cover behind the in-place detail card. */
    StorePackDetailViewPad *m_PackDetailViewPad; /**< The iPad-only embedded detail card. */
    BOOL m_IsAnimationing; /**< A detail open or close animation is running. */

    /** The pack currently mid-purchase; a plain assign. */
    __unsafe_unretained StorePackInfo *m_PurchasingPackInfo;
    /** Downloads the just-bought pack's musics. */
    StoreDownloadManager *m_DownloadManager;
    NSMutableArray *m_RestorePackInfo;  /**< The pack infos gathered during a restore. */
    NSMutableArray *m_RestoreProductID; /**< The product ids still awaiting a detail fetch. */
    /** Fetches a missing pack's detail during a restore. */
    StorePackInfoDownloader *m_StorePackInfoDownloader;
}

/**
 * @brief Build the catalogue for a tab host.
 * @param parent The owning store view controller.
 * @return The initialised controller.
 */
- (instancetype)initWithParent:(StoreViewController *)parent;

/**
 * @brief Mark that the store is closing, so in-flight callbacks can bail.
 */
- (void)startStoreClose;
/**
 * @brief Whether a modal alert is on screen; it blocks the back button.
 * @return YES while an alert is up.
 */
- (BOOL)isAlertViewShowing;

/**
 * @brief The pack table's "show more" button action: flip the button to a loading title and
 * spinner, and kick off the next page fetch.
 * @ghidraAddress 0x494cc
 */
- (void)selectShowMore;

// Pack-list controller callbacks.

/**
 * @brief A pack-list page arrived.
 * @param controller The list controller that fetched it.
 */
- (void)packListDownloadSuccess:(StorePackListController *)controller;
/**
 * @brief A pack-list fetch failed.
 * @param controller The list controller that failed.
 * @param message The error message to surface.
 */
- (void)packListDownloadError:(StorePackListController *)controller
                 errorMessage:(NSString *)message;
/**
 * @brief A pack-list fetch returned no packs.
 * @param controller The list controller that fetched it.
 */
- (void)packListDownloadNothing:(StorePackListController *)controller;

// Error surface and restore bar button.

/**
 * @brief Show an error alert.
 * @param message The message to show.
 */
- (void)showError:(NSString *)message;
/**
 * @brief The restore bar-button action: begin restoring previous purchases.
 * @param sender The tapped button.
 */
- (void)pushBarBtnRestore:(id)sender;

// Detail navigation: the iPad in-place card and the phone push.

/**
 * @brief The promotion banner was tapped.
 * @param view The banner.
 * @param packID The pack it advertises.
 */
- (void)storePromotionViewTaped:(StorePromotionView *)view PackID:(int)packID;
/**
 * @brief The detail-open animation finished.
 * @param animationID The animation identifier.
 * @param finished Whether the animation ran to completion.
 * @param ctx The animation context.
 */
- (void)openDetailAnimStop:(NSString *)animationID
                  finished:(NSNumber *)finished
                   context:(void *)ctx;
/**
 * @brief The detail-open animation started from the promotion banner finished.
 * @param animationID The animation identifier.
 * @param finished Whether the animation ran to completion.
 * @param ctx The animation context.
 */
- (void)openDetailAnimStopFromPromotion:(NSString *)animationID
                               finished:(NSNumber *)finished
                                context:(void *)ctx;
/**
 * @brief The detail-close animation finished.
 * @param animationID The animation identifier.
 * @param finished Whether the animation ran to completion.
 * @param ctx The animation context.
 */
- (void)closeDetailAnimStop:(NSString *)animationID
                   finished:(NSNumber *)finished
                    context:(void *)ctx;
/**
 * @brief The detail card asked to buy its pack.
 * @param packInfo The pack to purchase.
 */
- (void)detailViewStartPurchase:(StorePackInfo *)packInfo;
/**
 * @brief The detail card asked to close.
 */
- (void)detailViewClose;
/**
 * @brief The store dialog's cancel action.
 * @param sender The tapped control.
 */
- (void)storeDialogCancel:(id)sender;

// Purchase, download and restore.

/**
 * @brief Begin downloading a purchased pack's musics.
 * @param packInfo The pack to download.
 */
- (void)startDownloadPackMusics:(StorePackInfo *)packInfo;
/**
 * @brief Re-download a pack's musics after a failure.
 * @param packInfo The pack to download.
 */
- (void)reDownloadPackMusics:(StorePackInfo *)packInfo;
/**
 * @brief Merge a pack's song metadata into MusicManager.
 * @param packInfo The pack whose songs to record.
 * @param save YES to persist the purchased-music list afterwards.
 */
- (void)updateMusicInfo:(StorePackInfo *)packInfo Save:(BOOL)save;
/**
 * @brief Refresh the table row for a pack that has just been purchased.
 * @param packInfo The purchased pack.
 */
- (void)updatePurchasedTableCell:(StorePackInfo *)packInfo;
/**
 * @brief A purchase completed and its receipt verified.
 * @param productID The purchased product identifier.
 */
- (void)purchaseSucceeded:(NSString *)productID;
/**
 * @brief A purchase failed.
 * @param productID The product identifier.
 * @param error What went wrong.
 */
- (void)purchaseFailed:(NSString *)productID error:(NSError *)error;
/**
 * @brief Queue a pack gathered during a restore.
 * @param packInfo The restored pack.
 */
- (void)addRestorePackInfo:(StorePackInfo *)packInfo;
/**
 * @brief Advance to the next pack awaiting a detail fetch during a restore.
 * @return YES when another pack was started.
 */
- (BOOL)nextRestorePackInfo;
/**
 * @brief Ask the player whether to download every restored pack's musics now.
 */
- (void)askDownloadAllMusics;
/**
 * @brief Download every restored pack's musics.
 */
- (void)restoreDownloadAllMusics;
/**
 * @brief The restore completed with at least one product.
 */
- (void)restoreSucceeded;
/**
 * @brief The restore failed.
 * @param error What went wrong.
 */
- (void)restoreFailed:(NSError *)error;
/**
 * @brief The restore completed but found nothing to restore.
 */
- (void)restoreNothing;

// Download-manager, pack-info-downloader and image-downloader delegates.

/**
 * @brief A pack's detail fetch completed.
 * @param downloader The finished downloader.
 */
- (void)storePackInfoDownloaderFinished:(StorePackInfoDownloader *)downloader;
/**
 * @brief A pack's detail fetch failed.
 * @param downloader The failed downloader.
 */
- (void)storePackInfoDownloaderError:(StorePackInfoDownloader *)downloader;
/**
 * @brief The download manager started a task.
 * @param manager The download manager.
 */
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager;
/**
 * @brief The download manager finished every task.
 * @param manager The download manager.
 */
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager;
/**
 * @brief The download manager failed.
 * @param manager The download manager.
 */
- (void)downloadManagerFailed:(StoreDownloadManager *)manager;
/**
 * @brief The download manager made progress.
 * @param manager The download manager.
 */
- (void)downloadManagerProceed:(StoreDownloadManager *)manager;
/**
 * @brief A jacket image finished downloading.
 * @param downloader The finished downloader.
 * @param indexPath The table row to refresh.
 */
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath;
/**
 * @brief A jacket image failed to download.
 * @param downloader The failed downloader.
 * @param indexPath The table row that was waiting on it.
 */
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath;
/**
 * @brief Cancel every in-flight jacket download.
 */
- (void)stopDownloadArtworks;

// Alert delegate and NSURLConnection stubs.

/**
 * @brief An alert button was tapped.
 * @param alertView The alert that was dismissed.
 * @param index 0 for the cancel button, 1 for the other button.
 */
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index;
/**
 * @brief An NSURLConnection finished loading.
 * @param connection The finished connection.
 */
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
/**
 * @brief An NSURLConnection failed.
 * @param connection The failed connection.
 * @param error What went wrong.
 */
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;

/**
 * @brief The number of pack rows currently in the table.
 * @return The row count.
 */
- (NSInteger)numPackRows;

// Detail-open helpers, implemented in StoreMainViewController.mm alongside the -viewDidLoad
// cluster: the phone push, the iPad in-place card, and the dim-cover tap dismiss.

/**
 * @brief Push the phone detail screen for a pack.
 * @param packID The pack to show.
 */
- (void)showDetailViewForPhone:(int)packID;
/**
 * @brief A pack cell or promotion view was selected.
 * @param packView The selected view.
 */
- (void)packViewSelected:(id)packView;
/**
 * @brief The iPad dim cover was tapped; dismiss the detail card.
 * @param sender The tap recogniser.
 */
- (void)handleTapCoverView:(id)sender;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
