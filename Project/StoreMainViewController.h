//
//  StoreMainViewController.h
//  pop'n rhythmin
//
//  The store's main tab: browses the song-pack catalogue in a table, drives two
//  StorePackListControllers (the normal list and the recommend list), lazily loads
//  jacket artwork, and pushes pack-detail screens. This file is grown incrementally
//  from the decompilation; the constructor + the methods the host calls land first,
//  the table datasource / download callbacks / detail navigation follow.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    initWithParent: @ 0x42b40   startStoreClose @ 0x4a2d8   isAlertViewShowing @ 0x4a2ec
//    packListDownloadSuccess: @ 0x449e0 (reconstructed alongside the table methods)
//

#import <UIKit/UIKit.h>
#import "StorePackListController.h"
#import "StoreDownloadManager.h"
#import "StorePackInfoDownloader.h"
#import "ImageDownloader.h"
#import "StorePromotionView.h"
#import "CommonAlertView.h"

@class StoreViewController;
@class StorePackDetailViewPad;
@class StorePackInfo;

@interface StoreMainViewController
    : UIViewController <StorePackListControllerDelegate, StoreDownloadManagerDelegate,
                        StorePackInfoDownloaderDelegate, ImageDownloaderDelegate,
                        StorePromotionViewDelegate, CommonAlertViewDelegate,
                        UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate> {
    __weak StoreViewController *m_StoreViewCtrl;      // owning tab host (not retained)
    StorePackListController *m_PackListCtrl;          // normal catalogue
    StorePackListController *m_RecommendPackListCtrl; // recommend catalogue
    NSMutableDictionary *m_ArtworkDownloaders;        // jacket ImageDownloaders by index
    BOOL m_IsPad;
    int m_OffsetForOS;                                // iOS7 layout nudge (46 on phone)
    BOOL m_IsStoreClosing;                            // set while the host fades out
    BOOL _isAlertViewShowing;                         // an alert is up (atomic)

    // Pack-table "show more" controls (built by viewDidLoad, driven by selectShowMore).
    UIButton *m_ShowMoreButton;                       // the "▼ SHOW MORE ▼" / "読み込み中..." button
    UIActivityIndicatorView *m_ShowMoreIndicator;     // spinner shown while fetching more
    BOOL m_IsLoadingMoreList;                         // a "load more packs" fetch is in flight

    // Promotion banner + its background dummy (top of the pack table).
    StorePromotionView *m_PromotionView;
    UIImageView *m_PromotionViewDummy;
    UILabel *m_PackTableLabel;                        // shown once the first page arrives

    // Alternating pack-cell backdrops (store_pack_bg_0/1).
    UIImage *m_PackBgImage0;
    UIImage *m_PackBgImage1;

    // The "復元" (restore) bar button, lazily added on the first successful page.
    UIButton *m_RestoreButton;

    // iPad-only in-place detail: a dim cover + an embedded detail card.
    UIView *m_CoverViewPad;
    StorePackDetailViewPad *m_PackDetailViewPad;
    BOOL m_IsAnimationing;                            // a detail open/close animation is running

    // Purchase / download / restore state.
    __unsafe_unretained StorePackInfo *m_PurchasingPackInfo; // pack currently mid-purchase (assign)
    StoreDownloadManager *m_DownloadManager;          // downloads the just-bought pack's musics
    NSMutableArray *m_RestorePackInfo;                // pack infos gathered during a restore
    NSMutableArray *m_RestoreProductID;               // product IDs still awaiting detail fetch
    StorePackInfoDownloader *m_StorePackInfoDownloader; // fetches a missing pack's detail on restore
}

- (instancetype)initWithParent:(StoreViewController *)parent;

// Marks that the store is closing so in-flight callbacks can bail.
- (void)startStoreClose;
// YES while a modal alert is on screen (blocks the back button).
- (BOOL)isAlertViewShowing;

// The pack table's "show more" button action: flips the button to a loading title +
// spinner and kicks off the next page fetch. Ghidra: @ 0x494cc.
- (void)selectShowMore;

// --- Pack-list controller callbacks -------------------------------------------------
- (void)packListDownloadSuccess:(StorePackListController *)controller;
- (void)packListDownloadError:(StorePackListController *)controller errorMessage:(NSString *)message;
- (void)packListDownloadNothing:(StorePackListController *)controller;

// --- Error surface + restore bar button ---------------------------------------------
- (void)showError:(NSString *)message;
- (void)pushBarBtnRestore:(id)sender;

// --- Detail navigation (iPad in-place card + phone push) -----------------------------
- (void)storePromotionViewTaped:(StorePromotionView *)view PackID:(int)packID;
- (void)openDetailAnimStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)ctx;
- (void)openDetailAnimStopFromPromotion:(NSString *)animationID
                               finished:(NSNumber *)finished
                                context:(void *)ctx;
- (void)closeDetailAnimStop:(NSString *)animationID
                   finished:(NSNumber *)finished
                    context:(void *)ctx;
- (void)detailViewStartPurchase:(StorePackInfo *)packInfo;
- (void)detailViewClose;
- (void)storeDialogCancel:(id)sender;

// --- Purchase / download / restore ---------------------------------------------------
- (void)startDownloadPackMusics:(StorePackInfo *)packInfo;
- (void)reDownloadPackMusics:(StorePackInfo *)packInfo;
- (void)updateMusicInfo:(StorePackInfo *)packInfo Save:(BOOL)save;
- (void)updatePurchasedTableCell:(StorePackInfo *)packInfo;
- (void)purchaseSucceeded:(NSString *)productID;
- (void)purchaseFailed:(NSString *)productID error:(NSError *)error;
- (void)addRestorePackInfo:(StorePackInfo *)packInfo;
- (BOOL)nextRestorePackInfo;
- (void)askDownloadAllMusics;
- (void)restoreDownloadAllMusics;
- (void)restoreSucceeded;
- (void)restoreFailed:(NSError *)error;
- (void)restoreNothing;

// --- Download-manager / pack-info-downloader / image-downloader delegates -------------
- (void)storePackInfoDownloaderFinished:(StorePackInfoDownloader *)downloader;
- (void)storePackInfoDownloaderError:(StorePackInfoDownloader *)downloader;
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager;
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager;
- (void)downloadManagerFailed:(StoreDownloadManager *)manager;
- (void)downloadManagerProceed:(StoreDownloadManager *)manager;
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath;
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath;
- (void)stopDownloadArtworks;

// --- Alert delegate + NSURLConnection stubs ------------------------------------------
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;

// --- Pack-table row bookkeeping ------------------------------------------------------
- (NSInteger)numPackRows;

// Detail-open helpers (implemented in StoreMainViewController.mm alongside the viewDidLoad
// cluster): phone push / pad in-place card / dim-cover tap dismiss.
- (void)showDetailViewForPhone:(int)packID;
- (void)packViewSelected:(id)packView;
- (void)handleTapCoverView:(id)sender;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
