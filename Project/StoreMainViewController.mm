//
//  StoreMainViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreMainViewController.h"
#import "StoreViewController.h"
#import "neEngineBridge.h"

@implementation StoreMainViewController

// @ 0x42b40 — set up the tab item, the two pack-list controllers, the artwork
// cache, and the per-OS layout offset.
- (instancetype)initWithParent:(StoreViewController *)parent {
    if ((self = [super init])) {
        m_StoreViewCtrl = parent;

        // Tab item: "購入" ("Purchase") — Ghidra CFString @ 0x136728.
        self.tabBarItem.title = @"購入";
        [self.tabBarItem
            setFinishedSelectedImage:[UIImage imageNamed:@"store_icon_store"]
             withFinishedUnselectedImage:[UIImage imageNamed:@"store_icon_store"]];

        m_PackListCtrl = [[StorePackListController alloc] init];
        m_PackListCtrl.delegate = self;
        m_RecommendPackListCtrl = [[StorePackListController alloc] init];
        m_RecommendPackListCtrl.delegate = self;

        m_ArtworkDownloaders = [[NSMutableDictionary alloc] initWithCapacity:32];

        neSceneManager::shared();
        m_IsPad = neSceneManager::isPadDisplay();
        m_OffsetForOS = 0;
        // On iOS 7+ the phone layout nudges content down by 46pt (status/nav bar).
        if (UIDevice.currentDevice.systemVersion.floatValue >= 7.0f) {
            m_OffsetForOS = m_IsPad ? 0 : 46;
        }
    }
    return self;
}

// @ 0x42d48 — root view backdrop. Phone: opaque light-grey table backdrop.
// iPad: a clear view over a tiled "friman_bg" pattern image.
- (void)loadView {
    [super loadView];
    self.view.opaque = YES;

    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        // RGB 226/227/228 (Ghidra 0x3f62e2e3 / 0x3f63e3e4 / 0x3f64e4e5).
        self.view.backgroundColor = [UIColor colorWithRed:226.0f / 255.0f
                                                    green:227.0f / 255.0f
                                                     blue:228.0f / 255.0f
                                                    alpha:1.0f];
    } else {
        self.view.backgroundColor = [UIColor clearColor];
        UIImageView *bg =
            [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"friman_bg"]] autorelease];
        [self.view addSubview:bg];
    }
    self.view.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.exclusiveTouch = YES;
}

// @ 0x42eec — viewDidLoad builds the full pack-browser hierarchy: the pack
// UITableView (tag 10000) with its "show more" button + spinner + "push up to show
// more" label (tag 100000) + store_fun image (tag 0x186a1), a loading label (tag
// 0x2711) with a spinner, an empty-state label (tag 0x2712), the promotion banner
// (StorePromotionView, tag 0x2775) + its dummy, and — on iPad — an inset table, a
// dim cover view (handleTapCoverView:) and an embedded StorePackDetailViewPad; plus
// the stretchable pack-cell backgrounds (store_pack_bg_0/1).
//
// RECONSTRUCTION DEFERRED (dep audit updated 2026-07-02). The original blocker was
// stale: StorePromotionView (fully reconstructed) and StorePackDetailViewPad (a data-
// holder) both exist now. The remaining work is a connected chunk, so it is done as
// one dedicated pass rather than piecemeal (leaving dangling refs would break the
// no-unimplemented-refs rule). It needs, all in one go:
//   * 9 new ivars: m_PromotionView (StorePromotionView*), m_PromotionViewDummy
//     (UIImageView*), m_PackTableLabel (UILabel*), m_ShowMoreButton (UIButton*),
//     m_ShowMoreIndicator (UIActivityIndicatorView*), m_CoverViewPad (UIView*),
//     m_PackDetailViewPad (StorePackDetailViewPad*), m_PackBgImage0/1 (UIImage*),
//     plus m_IsLoadingMoreList (BOOL, used by selectShowMore).
//   * action handlers selectShowMore (@0x494cc) + handleTapCoverView: (@0x45940),
//     which in turn need closeDetailAnimStop:finished:context:, StorePackListController
//     -startFetchingPack:, and StorePackDetailViewPad -cancelLoading/-stopSample.
//   * geometry: most rects are self.view.bounds-derived (center = bounds.w*0.5,
//     bounds.h*0.5 +/- an offset) and thus recoverable; the StorePromotionView /
//     StorePackDetailViewPad initWithFrame: rects are NEON-spilled and need per-call-
//     site disassembly (iPad promo = 730x240 @0x44368000/0x43700000, detail = 650x650
//     @0x44228000 are visible in the pseudocode; the phone promo frame is spilled).
// Full structure + decoded float constants are catalogued in HANDOFF.md.

// @ 0x4a2d8
- (void)startStoreClose {
    m_IsStoreClosing = YES;
}

// @ 0x4a2ec
- (BOOL)isAlertViewShowing {
    return _isAlertViewShowing;
}

// @ 0x494cc — tapped the pack table's "show more" footer button. Guarded so a second
// tap while a fetch is in flight is ignored. Swaps the button caption to the loading
// text (byte-verified CFString @ 0x136798) without moving it (capture the centre,
// -sizeToFit to the new title, then restore the centre), reveals the spinner, hides the
// "push up to show more" hint label (tag 100000), and asks the pack list for the next
// page (-1 = "the page after the last one loaded").
- (void)selectShowMore {
    if (m_IsLoadingMoreList) {
        return;
    }
    m_IsLoadingMoreList = YES;

    [m_ShowMoreButton setTitle:@"読み込み中..." forState:UIControlStateNormal];  // "Loading..."
    CGPoint center = m_ShowMoreButton ? m_ShowMoreButton.center : CGPointZero;
    [m_ShowMoreButton sizeToFit];
    m_ShowMoreButton.center = center;

    m_ShowMoreIndicator.hidden = NO;
    [[self.view viewWithTag:100000] setHidden:YES];

    [m_PackListCtrl startFetchingPack:-1];
}

- (void)dealloc {
    [m_PackListCtrl release];
    [m_RecommendPackListCtrl release];
    [m_ArtworkDownloaders release];
    [super dealloc];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
