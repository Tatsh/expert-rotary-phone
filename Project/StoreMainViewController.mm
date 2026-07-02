//
//  StoreMainViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreMainViewController.h"
#import "StoreViewController.h"

// Engine glue: the scene manager singleton + its cached iPad-display flag
// (Ghidra DAT_00187b84, set at boot from the device idiom).
extern "C" {
void *NESceneManager_shared(void);
extern char g_IsPadDisplay;
}

@implementation StoreMainViewController

// @ 0x42b40 — set up the tab item, the two pack-list controllers, the artwork
// cache, and the per-OS layout offset.
- (instancetype)initWithParent:(StoreViewController *)parent {
    if ((self = [super init])) {
        m_StoreViewCtrl = parent;

        // Tab item: "ストア" (Ghidra cf_eQ; Japanese, glyphs not byte-verified).
        self.tabBarItem.title = @"ストア";
        [self.tabBarItem
            setFinishedSelectedImage:[UIImage imageNamed:@"store_icon_store"]
             withFinishedUnselectedImage:[UIImage imageNamed:@"store_icon_store"]];

        m_PackListCtrl = [[StorePackListController alloc] init];
        m_PackListCtrl.delegate = self;
        m_RecommendPackListCtrl = [[StorePackListController alloc] init];
        m_RecommendPackListCtrl.delegate = self;

        m_ArtworkDownloaders = [[NSMutableDictionary alloc] initWithCapacity:32];

        NESceneManager_shared();
        m_IsPad = g_IsPadDisplay;
        m_OffsetForOS = 0;
        // On iOS 7+ the phone layout nudges content down by 46pt (status/nav bar).
        if (UIDevice.currentDevice.systemVersion.floatValue >= 7.0f) {
            m_OffsetForOS = m_IsPad ? 0 : 46;
        }
    }
    return self;
}

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
