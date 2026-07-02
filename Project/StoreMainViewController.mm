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
// the stretchable pack-cell backgrounds (store_pack_bg_0/1). RECONSTRUCTION DEFERRED:
// the method's CGRect geometry is largely unrecoverable (ARM NEON vector spills in
// the decompiler), and it depends on StorePromotionView + StorePackDetailViewPad
// which are not yet reconstructed. Tracked in HANDOFF.md.

// @ 0x4a2d8
- (void)startStoreClose {
    m_IsStoreClosing = YES;
}

// @ 0x4a2ec
- (BOOL)isAlertViewShowing {
    return _isAlertViewShowing;
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
