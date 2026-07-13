//
//  StoreAcvManageViewController.h
//  pop'n rhythmin
//
//  The store's arcade-viewer manager tab: the sibling of
//  StoreManageViewController for arcade-viewer content (delete / re-download).
//  Lists the purchased arcade- viewer songs, offers a per-row delete /
//  re-download button, runs an integrity "check" pass (fetching missing
//  arcade-song info) on load, and drives the file download through
//  StoreDownloadManager with the shared store modal dialog.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithParent: @ 0x8c630, loadView @ 0x8c7f0, dealloc @ 0x8e748).
//

#import <UIKit/UIKit.h>

#import "CommonAlertView.h"      // CommonAlertViewDelegate
#import "Downloader.h"           // DownloaderDelegate
#import "StoreDownloadManager.h" // StoreDownloadManagerDelegate

@class StoreViewController;

@interface StoreAcvManageViewController : UIViewController <UITableViewDataSource,
                                                            UITableViewDelegate,
                                                            DownloaderDelegate,
                                                            StoreDownloadManagerDelegate,
                                                            CommonAlertViewDelegate> {
    __weak StoreViewController *m_StoreViewCtrl; // owning tab host (not retained)
    int m_WorkingIndex;                          // row currently acting (-1 = none)
    UIImage *m_ImgDelete;                        // "manage_delete" action icon
    UIImage *m_ImgDownload;                      // "manage_download" action icon
    BOOL m_IsPad;
    UITableView *m_TableView;           // the manage list
    NSMutableArray *m_CheckMusicIds;    // owned-music ids still needing an AC-info fetch
    CommonAlertView *m_DeleteAlertView; // delete-confirm alert
    StoreDownloadManager *m_DlManager;  // active file download (nil when idle)
    Downloader *m_InfoDownloader;       // AC-info fetch / integrity check (nil when idle)
}

- (instancetype)initWithParent:(StoreViewController *)parent;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
