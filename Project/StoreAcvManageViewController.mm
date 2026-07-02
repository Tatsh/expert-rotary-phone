//
//  StoreAcvManageViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreAcvManageViewController.h"
#import "StoreViewController.h"

extern "C" {
void *NESceneManager_shared(void);
extern char g_IsPadDisplay;   // Ghidra DAT_00187b84
}

@implementation StoreAcvManageViewController

// @ 0x8c630 — identical to StoreManageViewController but for the arcade viewer.
- (instancetype)initWithParent:(StoreViewController *)parent {
    if ((self = [super init])) {
        m_StoreViewCtrl = parent;
        m_WorkingIndex = -1;

        // Tab item: "ビューア管理" (Ghidra cf_0000000000; Japanese, glyphs not
        // byte-verified).
        self.tabBarItem.title = @"ビューア管理";
        [self.tabBarItem
            setFinishedSelectedImage:[UIImage imageNamed:@"store_icon_manage2"]
             withFinishedUnselectedImage:[UIImage imageNamed:@"store_icon_manage2"]];

        m_ImgDelete = [[UIImage imageNamed:@"manage_delete"] retain];
        m_ImgDownload = [[UIImage imageNamed:@"manage_download"] retain];

        NESceneManager_shared();
        m_IsPad = g_IsPadDisplay;
        if (m_IsPad) {
            self.view.backgroundColor =
                [UIColor colorWithPatternImage:[UIImage imageNamed:@"friman_bg"]];
        }
    }
    return self;
}

- (void)dealloc {
    [m_ImgDelete release];
    [m_ImgDownload release];
    [super dealloc];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
