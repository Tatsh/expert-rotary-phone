//
//  StoreDownloadManager.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreDownloadManager.h"

#import <UIKit/UIKit.h> // UIApplication.idleTimerDisabled (keep the device awake during a download)

#import "MusicManager.h"
#import "StoreDownloadTask.h"

@implementation StoreDownloadManager {
    Downloader *m_FileDownloader; // the in-flight per-file download
    NSArray *m_Tasks;             // StoreDownloadTask list (immutable copy)
    NSUInteger m_CurrentIndex;    // task being downloaded
    BOOL m_IsStarted;             // guards -start against re-entry
}

// @ 0x41fec — keep an immutable copy of the task list; bail out if none was
// given.
// @complete
- (instancetype)initWithTasks:(NSArray *)tasks delegate:(id<StoreDownloadManagerDelegate>)delegate {
    if (tasks == nil) {
        return nil;
    }
    self = [super init];
    if (self) {
        m_Tasks = [[NSArray alloc] initWithArray:tasks];
        _delegate = delegate;
        m_IsStarted = NO;
    }
    return self;
}

// @ 0x42090 — progress (0..1) of the file currently downloading.
// @complete
- (float)currentProgress {
    return [m_FileDownloader currentProgress];
}

// @ 0x420b0 — overall progress across the whole queue.
// @complete
- (float)overallProgress {
    return ((float)self.currentIndex + self.currentProgress) / (float)self.numTasks;
}

// @ 0x42120 — number of files in the queue.
// @complete
- (NSUInteger)numTasks {
    return m_Tasks.count;
}

// @ 0x42140 — kick off the queue (once): keep the screen awake and start the
// first file.
// @complete
- (void)start {
    if (m_IsStarted) {
        return;
    }
    UIApplication.sharedApplication.idleTimerDisabled = YES;
    m_CurrentIndex = 0;
    StoreDownloadTask *task = m_Tasks[0];
    m_FileDownloader = [[Downloader alloc] initWithURL:[NSURL URLWithString:task.fileURL]
                                              delegate:self];
    [m_FileDownloader startDownloading];
    m_IsStarted = YES;
    if ([_delegate respondsToSelector:@selector(downloadManagerStartTask:)]) {
        [_delegate performSelector:@selector(downloadManagerStartTask:) withObject:self];
    }
}

// @ 0x422a0 — abort the in-flight download and let the screen sleep again.
// @complete
- (void)cancel {
    if (m_FileDownloader == nil) {
        return;
    }
    [m_FileDownloader cancel];
    m_FileDownloader = nil;
    UIApplication.sharedApplication.idleTimerDisabled = NO;
}

#pragma mark - DownloaderDelegate

// @ 0x42314 — write the finished file to its path; on success mark the music
// library dirty and advance to the next file (or finish); on failure notify.
// The three outcomes share the trailing delegate notification.
// @complete
- (void)downloaderFinished:(Downloader *)downloader {
    NSData *data = [m_FileDownloader getData];
    m_FileDownloader = nil;

    SEL notify;
    StoreDownloadTask *task = m_Tasks[m_CurrentIndex];
    NSError *error = nil;
    if (![data writeToFile:task.filePath options:NSDataWritingAtomic error:&error]) {
        notify = @selector(downloadManagerFailed:);
    } else {
        [[MusicManager getInstance] setMusicDataArrayDirty];
        m_CurrentIndex++;
        if (m_CurrentIndex < m_Tasks.count) {
            StoreDownloadTask *next = m_Tasks[m_CurrentIndex];
            m_FileDownloader = [[Downloader alloc] initWithURL:[NSURL URLWithString:next.fileURL]
                                                      delegate:self];
            [m_FileDownloader startDownloading];
            notify = @selector(downloadManagerStartTask:);
        } else {
            UIApplication.sharedApplication.idleTimerDisabled = NO;
            notify = @selector(downloadManagerCompleted:);
        }
    }
    if ([_delegate respondsToSelector:notify]) {
        // The selector is one of the void delegate callbacks resolved above, so
        // it returns nothing to leak; silence the unknown-selector ARC warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [_delegate performSelector:notify withObject:self];
#pragma clang diagnostic pop
    }
}

// @ 0x42568 — forward per-chunk download progress to the delegate.
// @complete
- (void)downloaderProceed:(Downloader *)downloader {
    if ([_delegate respondsToSelector:@selector(downloadManagerProceed:)]) {
        [_delegate performSelector:@selector(downloadManagerProceed:) withObject:self];
    }
}

// @ 0x425bc — a file download failed: let the screen sleep, drop the
// downloader, notify the delegate.
// @complete
- (void)downloaderError:(Downloader *)downloader {
    UIApplication.sharedApplication.idleTimerDisabled = NO;
    if (m_FileDownloader != nil) {
        m_FileDownloader = nil;
    }
    if ([_delegate respondsToSelector:@selector(downloadManagerFailed:)]) {
        [_delegate performSelector:@selector(downloadManagerFailed:) withObject:self];
    }
}

#pragma mark - Accessors

// @ 0x426e0
// @complete
- (NSUInteger)currentIndex {
    return m_CurrentIndex;
}

// @ 0x426f0
// @complete
- (NSArray *)tasks {
    return m_Tasks;
}

// @ 0x42664 — cancel any in-flight download before going away (ARC frees the
// ivars).
// @complete
- (void)dealloc {
    if (m_FileDownloader != nil) {
        [m_FileDownloader cancel];
        m_FileDownloader = nil;
    }
}

@end
