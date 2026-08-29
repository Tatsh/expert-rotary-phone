/**
 * @file
 * The launch-time "default data" downloader screen.
 *
 * MainViewController presents it (as _defaultDlViewController) when DownloadMain's file list
 * contains bundled data files that are missing or stale on disk; it downloads them one by one
 * behind a DownloadProgresView dialog, then notifies the root scene
 * (DefaultDownloadEndCallBack).
 *
 * Despite the "View" name this is a UIViewController subclass, verified from the Objective-C
 * class metadata: the superclass slot points at UIViewController, and callers use its .view and
 * -isFailed. Reconstructed from Ghidra project rb420, program PopnRhythmin
 * (initWithFileDataArray: @ 0xdd158, startOpenAnimation @ 0xddbe8). Built in
 * DefaultDataDownloadView.mm, since the neSceneManager singleton drives the root-VC end callback.
 */

#import <UIKit/UIKit.h>

@class DownloadProgresView;
@class Downloader;

/**
 * The launch-time "default data" downloader screen.
 */
@interface DefaultDataDownloadView : UIViewController {
    /** The progress dialog: spinner, bar and label. */
    DownloadProgresView *_downloadView;
    NSArray *_dlFileListDataArray; /**< The NSValue-wrapped DlFileListData entries to fetch. */
    Downloader *_downloader;       /**< The in-flight HTTP fetch; nil when idle. */
    int _downloadingIdx;           /**< The index of the file currently being fetched. */
    NSString *_filePath;           /**< The local destination path of the current file. */
    int _fileSize;                 /**< The expected size of the current file. */
    int _totalFileSize;            /**< The sum of every file's size: the progress denominator. */
    int _downloadedFileSize;       /**< The bytes committed so far: the progress numerator. */
    BOOL _isFailed;                /**< A fetch, verify or write failed; it backs -isFailed. */
    BOOL _isAnimationing;          /**< An open or close fade is running; it guards re-entry. */
    int _tryCnt;                   /**< The retry counter for the current file; the cap is 3. */
}

/**
 * Take the DownloadMain file list, sum the total size and build the progress dialog.
 * @param fileDataArray An NSArray of NSValue-wrapped DlFileListData.
 * @return The initialised controller.
 * @ghidraAddress 0xdd158
 */
- (instancetype)initWithFileDataArray:(NSArray *)fileDataArray;

/**
 * Fade the view in over 0.3 s; endOpenAnimation then kicks off the first download.
 * @ghidraAddress 0xddbe8
 */
- (void)startOpenAnimation;

/** Set once any file's download, verify or write fails; MainViewController reads it back after
 * the screen closes. The accessors are atomic over the _isFailed ivar. Getter @ 0xde1a0, setter @
 * 0xde1b8. */
@property(assign) BOOL isFailed;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
