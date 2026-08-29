/**
 * @file
 * The store's arcade-viewer manager tab.
 *
 * It is the sibling of StoreManageViewController for arcade-viewer content, handling deletion and
 * re-download. It lists the purchased arcade-viewer songs, offers a per-row delete and re-download
 * button, runs an integrity "check" pass on load that fetches missing arcade-song info, and drives
 * the file download through StoreDownloadManager with the shared store modal dialog.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithParent: @ 0x8c630,
 * loadView @ 0x8c7f0, dealloc @ 0x8e748).
 */

#import <UIKit/UIKit.h>

#import "CommonAlertView.h"      // CommonAlertViewDelegate
#import "Downloader.h"           // DownloaderDelegate
#import "StoreDownloadManager.h" // StoreDownloadManagerDelegate

@class StoreViewController;

/**
 * The arcade-viewer song manager tab: it lists owned arcade songs and lets each be deleted
 * or re-downloaded.
 */
@interface StoreAcvManageViewController : UIViewController <UITableViewDataSource,
                                                            UITableViewDelegate,
                                                            DownloaderDelegate,
                                                            StoreDownloadManagerDelegate,
                                                            CommonAlertViewDelegate> {
    __weak StoreViewController *m_StoreViewCtrl; /**< The owning tab host; not retained. */
    int m_WorkingIndex;                          /**< The row currently acting; -1 when none. */
    UIImage *m_ImgDelete;                        /**< The "manage_delete" action icon. */
    UIImage *m_ImgDownload;                      /**< The "manage_download" action icon. */
    BOOL m_IsPad;                                /**< Whether this is the iPad layout. */
    UITableView *m_TableView;                    /**< The manage list. */
    NSMutableArray *m_CheckMusicIds;    /**< Owned-music ids still needing an arcade-info fetch. */
    CommonAlertView *m_DeleteAlertView; /**< The delete-confirm alert. */
    StoreDownloadManager *m_DlManager;  /**< The active file download; nil when idle. */
    /** The arcade-info fetch and integrity check; nil when idle. */
    Downloader *m_InfoDownloader;
}

/**
 * Build the manager for a tab host.
 * @param parent The owning store view controller.
 * @return The initialised controller.
 */
- (instancetype)initWithParent:(StoreViewController *)parent;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
