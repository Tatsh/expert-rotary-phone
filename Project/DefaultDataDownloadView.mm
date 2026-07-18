//
//  DefaultDataDownloadView.mm
//  pop'n rhythmin
//
//  See DefaultDataDownloadView.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin. Objective-C++ for the neSceneManager singleton
//  (root-VC end callback). The one-file-at-a-time download loop, retry-up-to-3
//  policy and progress arithmetic are byte-verified; the alert copy is the
//  exact Japanese literal from the __cfstring table (shared with the
//  invite-code screens).
//

#import "DefaultDataDownloadView.h"

#import "AppDelegate.h"         // +appAppSupportDirectory (non-.orb destination dir)
#import "CommonAlertView.h"     // failure alert
#import "DownloadMain.h"        // DlFileListData (NSValue payload)
#import "DownloadProgresView.h" // the progress dialog view
#import "Downloader.h"          // the HTTP fetch + DownloaderDelegate
#import "MusicManager.h"        // -getPathFromPurchased: (.orb destination path)
#import "RhUtil.h"              // getFileSize()
#import "neEngineBridge.h"      // neSceneManager::rootViewController

// Own privates + adopted delegate.
@interface DefaultDataDownloadView () <DownloaderDelegate>
- (BOOL)downloadWithIdx:(int)idx;
- (void)endOpenAnimation;
- (void)startCloseAnimation;
- (void)endCloseAnimation;
- (BOOL)isDigit:(NSString *)string;
- (void)setJustDownloadedSize;
@end

@implementation DefaultDataDownloadView

@synthesize isFailed = _isFailed;

// @ 0xdd158 — take the file list, sum the total size, build the progress
// dialog.
// Disassembly-verified: the enumeration accumulates each entry's size field
// (state buffer offset 0x30) into _totalFileSize, and the "Filecheck..." label
// is set before addSubview.
// @complete
- (instancetype)initWithFileDataArray:(NSArray *)fileDataArray {
    self = [super init];
    _dlFileListDataArray = fileDataArray; // @ retained
    if (self != nil) {
        for (NSValue *value in _dlFileListDataArray) {
            DlFileListData data;
            [value getValue:&data];
            _totalFileSize += data.size;
        }

        _downloadView = [[DownloadProgresView alloc] initWithFrame:self.view.frame];
        [_downloadView layout:NO];
        [_downloadView.progressView setProgress:0];
        [_downloadView.indicatorView startAnimating];
        [_downloadView.labelMessage setText:@"Filecheck..."];
        [self.view addSubview:_downloadView];
    }
    return self;
}

// viewDidLoad @ 0xdd3d4 — super-only override, omitted.
// didReceiveMemoryWarning @ 0xdd400 — super-only override, omitted.

// @ 0xdd42c — cancel any in-flight fetch on teardown (kept under ARC; the array
// / path are released by ARC).
// @complete
- (void)dealloc {
    if (_downloader != nil) {
        [_downloader cancel];
    }
}

// @ 0xdd4c0 — start fetching the file at `idx`, unless it is already present at
// the right size. Returns YES when a download was actually started. Sets
// _isFailed and returns NO on a hard error (bad music id, or a fetch already
// running).
// Disassembly-verified: the .orb pathExtension branch (getPathFromPurchased
// keyed by the numeric base name) versus the appAppSupportDirectory branch, the
// getFileSize equality skip (bl 0x5c48c; cmp; beq -> return NO), and the
// _downloader-nil gate that resets _tryCnt and starts the fetch.
// @complete
- (BOOL)downloadWithIdx:(int)idx {
    if (static_cast<int>(_dlFileListDataArray.count) <= idx) {
        return NO;
    }
    _filePath = nil; // @ release

    DlFileListData data;
    [_dlFileListDataArray[idx] getValue:&data];
    NSString *lastComponent = [data.url lastPathComponent];

    NSString *path;
    if (![[lastComponent pathExtension] isEqualToString:@"orb"]) {
        // Non-song data -> Application Support directory, keeping the file name.
        path = [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:lastComponent];
    } else {
        // A song .orb -> the purchased-music path keyed by its numeric id.
        NSString *base = [lastComponent stringByDeletingPathExtension];
        if (![self isDigit:base]) {
            _isFailed = YES;
            return NO;
        }
        path = [[MusicManager getInstance] getPathFromPurchased:[base intValue]];
    }

    // Already downloaded at the expected size -> nothing to do.
    if (data.size == getFileSize(path)) {
        return NO;
    }

    if (_downloader == nil) {
        _tryCnt = 0;
        _downloader = [[Downloader alloc] initWithURL:[NSURL URLWithString:data.url] delegate:self];
        [_downloader startDownloading];
        _filePath = path; // @ retain
        _fileSize = data.size;
        return YES;
    }

    _isFailed = YES;
    return NO;
}

// @ 0xdd6fc — a file finished: verify its size, write it, then advance to the
// next file that still needs fetching (or close when the list is exhausted /
// failed).
// Disassembly-verified: the length == _fileSize && writeToFile (options 0x1 =
// NSDataWritingAtomic) gate, the pre-increment of _downloadingIdx before the
// advance loop, the loop break on (started || _isFailed), and the trailing
// _downloadingIdx < count && !_isFailed proceed-versus-close branch. The
// progress fraction here is the unclamped _downloadedFileSize / _totalFileSize.
// @complete
- (void)downloaderFinished:(Downloader *)downloader {
    NSData *data = [_downloader getData];
    _downloader = nil; // @ release

    NSError *error = nil;
    if (data.length == static_cast<NSUInteger>(_fileSize) && [data writeToFile:_filePath
                                                                       options:NSDataWritingAtomic
                                                                         error:&error]) {
        // The just-finished entry is re-read here in the binary (result unused).
        DlFileListData finished;
        [_dlFileListDataArray[_downloadingIdx] getValue:&finished];

        NSUInteger next = ++_downloadingIdx;
        if (next < _dlFileListDataArray.count) {
            do {
                BOOL started = [self downloadWithIdx:_downloadingIdx];
                if (started || _isFailed) {
                    break;
                }
                _downloadingIdx++;
            } while (static_cast<NSUInteger>(_downloadingIdx) < _dlFileListDataArray.count);
        }
    } else {
        _isFailed = YES;
    }

    if (_isFailed) {
        CommonAlertView *alert =
            [[CommonAlertView alloc] initWithTitle:nil
                                           message:@"通信に失敗しました。\n電波状態"
                                                   @"の良い場所でやり直して下さい。"
                                          delegate:nil
                                 cancelButtonTitle:nil
                                 otherButtonTitles:@"OK"];
        [alert show];
    }

    if (static_cast<NSUInteger>(_downloadingIdx) < _dlFileListDataArray.count && !_isFailed) {
        [self setJustDownloadedSize];
        [_downloadView.progressView setProgress:static_cast<float>(_downloadedFileSize) /
                                                static_cast<float>(_totalFileSize)];
    } else {
        [_downloadView.indicatorView stopAnimating];
        [self startCloseAnimation];
    }
}

// @ 0xdd9cc — per-chunk progress: refresh the committed-bytes baseline, add the
// in-flight bytes and update the label / bar (clamped to 100%).
// Disassembly-verified: the vcmpe against 1.0 with vmov.ls that clamps the
// fraction to 1.0, the (int)(clamped * 100) "Downloading %d%%" label, and the
// clamped value passed to setProgress.
// @complete
- (void)downloaderProceed:(Downloader *)downloader {
    [self setJustDownloadedSize];
    _downloadedFileSize += [downloader currentSize];

    float progress = static_cast<float>(_downloadedFileSize) / static_cast<float>(_totalFileSize);
    if (progress > 1.0f) {
        progress = 1.0f;
    }
    [_downloadView.labelMessage
        setText:[NSString
                    stringWithFormat:@"Downloading %d%%", static_cast<int>(progress * 100.0f)]];
    [_downloadView.progressView setProgress:progress];
}

// @ 0xddaf4 — a fetch errored: retry up to 3 times, else fail + close.
// Disassembly-verified: cmp _tryCnt, #2; bgt fail (so _tryCnt < 3 retries),
// then _tryCnt++ and startDownloading, else set _isFailed, release the
// downloader, show the shared alert, and startCloseAnimation.
// @complete
- (void)downloaderError:(Downloader *)downloader {
    if (_tryCnt < 3) {
        _tryCnt++;
        [_downloader startDownloading];
    } else {
        _isFailed = YES;
        _downloader = nil; // @ release
        CommonAlertView *alert =
            [[CommonAlertView alloc] initWithTitle:nil
                                           message:@"通信に失敗しました。\n電波状態"
                                                   @"の良い場所でやり直して下さい。"
                                          delegate:nil
                                 cancelButtonTitle:nil
                                 otherButtonTitles:@"OK"];
        [alert show];
        [self startCloseAnimation];
    }
}

// @ 0xddbe8 — fade the view up to opaque over 0.3 s.
// @complete
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    self.view.alpha = 0;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.view.alpha = 1.0f;
    [UIView commitAnimations];
}

// @ 0xddcd8 — open finished: reset the guard + index, then start the first file
// that needs downloading. If none do (or one fails), close immediately.
// Disassembly-verified: the one-file-at-a-time advance loop (break on a started
// download after setting the "Downloading 0%%" label, else alert on _isFailed
// then _downloadingIdx++), and the trailing proceed-versus-close branch.
// @complete
- (void)endOpenAnimation {
    _isAnimationing = NO;
    _downloadingIdx = 0;

    if (_dlFileListDataArray.count != 0) {
        do {
            if ([self downloadWithIdx:_downloadingIdx]) {
                [_downloadView.labelMessage setText:[NSString stringWithFormat:@"Downloading 0%%"]];
                break;
            }
            if (_isFailed) {
                CommonAlertView *alert = [[CommonAlertView alloc]
                        initWithTitle:nil
                              message:@"通信に失敗しました。\n電波状態の良い場所でやり"
                                      @"直して下さい。"
                             delegate:nil
                    cancelButtonTitle:nil
                    otherButtonTitles:@"OK"];
                [alert show];
            }
            _downloadingIdx++;
        } while (static_cast<NSUInteger>(_downloadingIdx) < _dlFileListDataArray.count);
    }

    if (static_cast<NSUInteger>(_downloadingIdx) < _dlFileListDataArray.count && !_isFailed) {
        [self setJustDownloadedSize];
        [_downloadView.progressView setProgress:static_cast<float>(_downloadedFileSize) /
                                                static_cast<float>(_totalFileSize)];
        [_downloadView.indicatorView startAnimating];
    } else {
        [self startCloseAnimation];
    }
}

// @ 0xddf38 — fade the view out over 0.3 s.
// @complete
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    self.view.alpha = 1.0f;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0;
    [UIView commitAnimations];
}

// @ 0xde028 — pull the view and notify the root scene the default download
// closed.
// @complete
- (void)endCloseAnimation {
    [self.view removeFromSuperview];
    UIViewController *root = neSceneManager::rootViewController();
    [root performSelector:@selector(DefaultDownloadEndCallBack)];
    _isAnimationing = NO;
}

// @ 0xde084 — YES if `string` is all decimal digits (used to validate an .orb's
// numeric base name before treating it as a music id).
// @complete
- (BOOL)isDigit:(NSString *)string {
    NSCharacterSet *digits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    NSScanner *scanner = [NSScanner localizedScannerWithString:string];
    [scanner setCharactersToBeSkipped:nil];
    [scanner scanCharactersFromSet:digits intoString:nil];
    return scanner.isAtEnd;
}

// @ 0xde114 — recompute the committed-bytes baseline as the sum of every
// already- completed file's size (files before _downloadingIdx).
// Disassembly-verified: _downloadedFileSize is zeroed, then each entry's size
// field (struct offset 0x8) is summed for i in [0, _downloadingIdx).
// @complete
- (void)setJustDownloadedSize {
    _downloadedFileSize = 0;
    for (int i = 0; i < _downloadingIdx; i++) {
        DlFileListData data;
        [_dlFileListDataArray[i] getValue:&data];
        _downloadedFileSize += data.size;
    }
}

// isFailed @ 0xde1a0 / setIsFailed: @ 0xde1b8 — atomic synthesized accessors
// (@synthesize above).
// Disassembly-verified: both back a plain atomic BOOL ivar (getter ldrb + dmb +
// sxtb; setter dmb + strb + dmb), i.e. exactly a synthesized atomic get/set with
// no extra app logic.
// @complete

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
