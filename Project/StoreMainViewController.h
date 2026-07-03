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

@class StoreViewController;

@interface StoreMainViewController : UIViewController <StorePackListControllerDelegate> {
    __weak StoreViewController *m_StoreViewCtrl;      // owning tab host (not retained)
    StorePackListController *m_PackListCtrl;          // normal catalogue
    StorePackListController *m_RecommendPackListCtrl; // recommend catalogue
    NSMutableDictionary *m_ArtworkDownloaders;        // jacket ImageDownloaders by index
    BOOL m_IsPad;
    int m_OffsetForOS;                                // iOS7 layout nudge (46 on phone)
    BOOL m_IsStoreClosing;                            // set while the host fades out
    BOOL _isAlertViewShowing;                         // an alert is up (atomic)

    // Pack-table "show more" controls (built by viewDidLoad, driven by selectShowMore).
    UIButton *m_ShowMoreButton;                       // the "もっと見る" / "読み込み中..." button
    UIActivityIndicatorView *m_ShowMoreIndicator;     // spinner shown while fetching more
    BOOL m_IsLoadingMoreList;                         // a "load more packs" fetch is in flight
}

- (instancetype)initWithParent:(StoreViewController *)parent;

// Marks that the store is closing so in-flight callbacks can bail.
- (void)startStoreClose;
// YES while a modal alert is on screen (blocks the back button).
- (BOOL)isAlertViewShowing;

// The pack table's "show more" button action: flips the button to a loading title +
// spinner and kicks off the next page fetch. Ghidra: @ 0x494cc.
- (void)selectShowMore;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
