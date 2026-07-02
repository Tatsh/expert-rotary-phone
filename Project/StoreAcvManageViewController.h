//
//  StoreAcvManageViewController.h
//  pop'n rhythmin
//
//  The store's arcade-viewer manager tab: the sibling of StoreManageViewController
//  for arcade-viewer content (delete / re-download). Grown incrementally; the
//  constructor lands first.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithParent: @ 0x8c630).
//

#import <UIKit/UIKit.h>

@class StoreViewController;

@interface StoreAcvManageViewController : UIViewController {
    __weak StoreViewController *m_StoreViewCtrl;  // owning tab host (not retained)
    int m_WorkingIndex;                           // row currently acting (-1 = none)
    UIImage *m_ImgDelete;                         // "manage_delete" action icon
    UIImage *m_ImgDownload;                        // "manage_download" action icon
    BOOL m_IsPad;
}

- (instancetype)initWithParent:(StoreViewController *)parent;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
