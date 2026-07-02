//
//  StoreManageViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreManageViewController.h"
#import "StoreViewController.h"

#import "neEngineBridge.h"

@implementation StoreManageViewController

// @ 0x4bc40 — tab item + action icons; iPad gets a patterned background.
- (instancetype)initWithParent:(StoreViewController *)parent {
    if ((self = [super init])) {
        m_StoreViewCtrl = parent;
        m_WorkingIndex = -1;

        // Tab item: "リズミン" ("Rhythmin") — Ghidra CFString @ 0x136968.
        self.tabBarItem.title = @"リズミン";
        [self.tabBarItem
            setFinishedSelectedImage:[UIImage imageNamed:@"store_icon_manage"]
             withFinishedUnselectedImage:[UIImage imageNamed:@"store_icon_manage"]];

        m_ImgDelete = [[UIImage imageNamed:@"manage_delete"] retain];
        m_ImgDownload = [[UIImage imageNamed:@"manage_download"] retain];

        neSceneManager::shared();
        m_IsPad = neSceneManager::isPadDisplay();
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
