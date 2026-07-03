//
//  StoreManageViewController.h
//  pop'n rhythmin
//
//  The store's purchased-music manager tab: lists owned packs/songs with delete and
//  re-download actions. Grown incrementally; the constructor lands first.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithParent: @ 0x4bc40, loadView @ 0x4be00, and the table/download machinery
//  @ 0x4c308..0x4d9b0).
//

#import <UIKit/UIKit.h>

#import "CommonAlertView.h"        // CommonAlertViewDelegate
#import "Downloader.h"             // DownloaderDelegate
#import "StoreDownloadManager.h"   // StoreDownloadManagerDelegate

@class StoreViewController;

@interface StoreManageViewController : UIViewController
    <UITableViewDataSource, UITableViewDelegate,
     DownloaderDelegate, StoreDownloadManagerDelegate, CommonAlertViewDelegate> {
    __weak StoreViewController *m_StoreViewCtrl;  // owning tab host (not retained)
    int m_WorkingIndex;                           // row currently acting (-1 = none)
    UIImage *m_ImgDelete;                         // "manage_delete" action icon
    UIImage *m_ImgDownload;                        // "manage_download" action icon
    BOOL m_IsPad;
    UITableView *m_TableView;                     // the manage list, built in -loadView
    Downloader *m_InfoDownloader;                 // re-download step 1: fetch StoreMusicInfo JSON
    StoreDownloadManager *m_DlManager;            // re-download step 2: the audio-file queue
    CommonAlertView *m_DeleteAlertView;           // "delete this song?" confirmation
}

- (instancetype)initWithParent:(StoreViewController *)parent;

// Re-download the audio file for the row at m_WorkingIndex (after its StoreMusicInfo
// was refreshed). Ghidra: startDownloadMusic @ 0x4d1ec.
- (void)startDownloadMusic;

// Per-row action button (tag 0xE01F) target: download a missing song or confirm delete.
// Ghidra: pushCellButton: @ 0x4ce28.
- (void)pushCellButton:(id)sender;

// Abort button of the store's shared modal progress dialog. Ghidra: storeDialogCancel: @ 0x4d4b8.
- (void)storeDialogCancel:(id)sender;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
