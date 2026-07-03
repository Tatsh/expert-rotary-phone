//
//  DefaultDataDownloadView.h
//  pop'n rhythmin
//
//  The launch-time "default data" downloader screen. MainViewController presents it
//  (as _defaultDlViewController) when DownloadMain's file list contains bundled data
//  files that are missing / stale on disk; it downloads them one by one behind a
//  DownloadProgresView dialog, then notifies the root scene (DefaultDownloadEndCallBack).
//
//  Despite the "View" name this is a UIViewController subclass (verified from the ObjC
//  class metadata — superclass slot points at UIViewController, and callers use its
//  .view / -isFailed). Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithFileDataArray: @ 0xdd158, startOpenAnimation @ 0xddbe8). Built in
//  DefaultDataDownloadView.mm (Objective-C++: the neSceneManager singleton drives the
//  root-VC end callback).
//

#import <UIKit/UIKit.h>

@class DownloadProgresView;
@class Downloader;

@interface DefaultDataDownloadView : UIViewController {
    DownloadProgresView *_downloadView;     // the progress dialog (spinner + bar + label)
    NSArray *_dlFileListDataArray;          // NSValue-wrapped DlFileListData entries to fetch
    Downloader *_downloader;                // the in-flight HTTP fetch (nil when idle)
    int _downloadingIdx;                    // index of the file currently being fetched
    NSString *_filePath;                    // local destination path of the current file
    int _fileSize;                          // expected size of the current file
    int _totalFileSize;                     // sum of every file's size (progress denominator)
    int _downloadedFileSize;                // bytes committed so far (progress numerator)
    BOOL _isFailed;                         // a fetch/verify/write failed (backs -isFailed)
    BOOL _isAnimationing;                   // an open/close fade is running (guards re-entry)
    int _tryCnt;                            // retry counter for the current file (max 3)
}

// Take the DownloadMain file list (NSArray of NSValue-wrapped DlFileListData), sum the
// total size and build the progress dialog. Ghidra: @ 0xdd158.
- (instancetype)initWithFileDataArray:(NSArray *)fileDataArray;

// Fade the view in over 0.3 s; endOpenAnimation then kicks off the first download.
// Ghidra: @ 0xddbe8.
- (void)startOpenAnimation;

// Set once any file's download / verify / write fails; MainViewController reads it back
// after the screen closes. Atomic synthesized accessors — getter @ 0xde1a0
// (isFailed), setter @ 0xde1b8 (setIsFailed:); ivar _isFailed.
@property (assign) BOOL isFailed;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
