//
//  StoreAcvManageViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreAcvManageViewController.h"
#import "StoreViewController.h"

#import "neEngineBridge.h"

@implementation StoreAcvManageViewController

// @ 0x8c630 — identical to StoreManageViewController but for the arcade viewer.
- (instancetype)initWithParent:(StoreViewController *)parent {
    if ((self = [super init])) {
        m_StoreViewCtrl = parent;
        m_WorkingIndex = -1;

        // Tab item: "アーケードビューアー" ("Arcade Viewer") — Ghidra CFString @ 0x138a88.
        self.tabBarItem.title = @"アーケードビューアー";
        [self.tabBarItem
            setFinishedSelectedImage:[UIImage imageNamed:@"store_icon_manage2"]
             withFinishedUnselectedImage:[UIImage imageNamed:@"store_icon_manage2"]];

        m_ImgDelete = [UIImage imageNamed:@"manage_delete"];
        m_ImgDownload = [UIImage imageNamed:@"manage_download"];

        neSceneManager::shared();
        m_IsPad = neSceneManager::isPadDisplay();
        if (m_IsPad) {
            self.view.backgroundColor =
                [UIColor colorWithPatternImage:[UIImage imageNamed:@"friman_bg"]];
        }
    }
    return self;
}

// dealloc — ARC-omitted (released object ivars only).

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
