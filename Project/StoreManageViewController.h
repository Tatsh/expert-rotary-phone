/**
 * @file
 * @brief The store's purchased-music manager tab.
 *
 * It lists owned packs and songs with delete and re-download actions, and is grown incrementally;
 * the constructor lands first.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithParent: @ 0x4bc40,
 * loadView @ 0x4be00, and the table and download machinery @ 0x4c308..0x4d9b0).
 */

#import <UIKit/UIKit.h>

#import "CommonAlertView.h"      // CommonAlertViewDelegate
#import "Downloader.h"           // DownloaderDelegate
#import "StoreDownloadManager.h" // StoreDownloadManagerDelegate

@class StoreViewController;

/**
 * @brief The purchased-music manager tab: it lists owned songs and lets each be deleted or
 * re-downloaded.
 */
@interface StoreManageViewController : UIViewController <UITableViewDataSource,
                                                         UITableViewDelegate,
                                                         DownloaderDelegate,
                                                         StoreDownloadManagerDelegate,
                                                         CommonAlertViewDelegate> {
    __weak StoreViewController *m_StoreViewCtrl; /**< The owning tab host; not retained. */
    int m_WorkingIndex;                          /**< The row currently acting; -1 when none. */
    UIImage *m_ImgDelete;                        /**< The "manage_delete" action icon. */
    UIImage *m_ImgDownload;                      /**< The "manage_download" action icon. */
    BOOL m_IsPad;                                /**< Whether this is the iPad layout. */
    UITableView *m_TableView;                    /**< The manage list, built in -loadView. */
    /** Re-download step 1: fetch the StoreMusicInfo JSON. */
    Downloader *m_InfoDownloader;
    /** Re-download step 2: the audio-file queue. */
    StoreDownloadManager *m_DlManager;
    CommonAlertView *m_DeleteAlertView; /**< The "delete this song?" confirmation. */
}

/**
 * @brief Build the manager for a tab host.
 * @param parent The owning store view controller.
 * @return The initialised controller.
 */
- (instancetype)initWithParent:(StoreViewController *)parent;

/**
 * @brief Re-download the audio file for the row at m_WorkingIndex, after its StoreMusicInfo was
 * refreshed.
 * @ghidraAddress 0x4d1ec
 */
- (void)startDownloadMusic;

/**
 * @brief The per-row action button's target, tag 0xE01F: download a missing song, or confirm a
 * delete.
 * @param sender The tapped button.
 * @ghidraAddress 0x4ce28
 */
- (void)pushCellButton:(id)sender;

/**
 * @brief The abort button of the store's shared modal progress dialog.
 * @param sender The tapped control.
 * @ghidraAddress 0x4d4b8
 */
- (void)storeDialogCancel:(id)sender;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
