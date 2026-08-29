/**
 * @file
 * The sequential downloader for a list of purchased or updated files.
 *
 * It writes each file to its destination path, marks the music library dirty, and reports progress
 * to its delegate. Reconstructed from Ghidra project rb420, program PopnRhythmin
 * (initWithTasks:delegate: @ 0x41fec, start @ 0x42140, downloaderFinished: @ 0x42314).
 */

#import <Foundation/Foundation.h>

#import "Downloader.h"

@class StoreDownloadManager;

/**
 * Receives the download queue's progress and outcome.
 */
@protocol StoreDownloadManagerDelegate <NSObject>
@optional
/**
 * The next file started downloading.
 * @param manager The download manager.
 */
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager;
/**
 * The current download made progress.
 * @param manager The download manager.
 */
- (void)downloadManagerProceed:(StoreDownloadManager *)manager;
/**
 * Every file finished.
 * @param manager The download manager.
 */
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager;
/**
 * A download or write failed.
 * @param manager The download manager.
 */
- (void)downloadManagerFailed:(StoreDownloadManager *)manager;
@end

/**
 * Downloads a queue of files one at a time, reporting per-file and overall progress.
 */
@interface StoreDownloadManager : NSObject <DownloaderDelegate>

/** The progress and outcome delegate. */
@property(nonatomic, assign) id<StoreDownloadManagerDelegate> delegate;

/** The immutable copy of the task list this manager was created with. Getter @ 0x426f0. */
@property(nonatomic, readonly) NSArray *tasks;
/** The index of the file currently downloading. Getter @ 0x426e0. */
@property(nonatomic, readonly) NSUInteger currentIndex;
/** The number of files in the queue, equal to `tasks.count`. Getter @ 0x42120. */
@property(nonatomic, readonly) NSUInteger numTasks;
/** The progress of the file currently downloading, in [0, 1]. Getter @ 0x42090. */
@property(nonatomic, readonly) float currentProgress;
/** The overall progress, `(currentIndex + currentProgress) / numTasks`, in [0, 1]. Getter @
 * 0x420b0. */
@property(nonatomic, readonly) float overallProgress;

/**
 * Create a manager for a list of downloads. The list is copied.
 * @param tasks The StoreDownloadTask list, each carrying a file URL and a local path.
 * @param delegate The progress and outcome delegate.
 * @return The initialised manager, or nil when @p tasks is nil.
 * @ghidraAddress 0x41fec
 */
- (instancetype)initWithTasks:(NSArray *)tasks delegate:(id<StoreDownloadManagerDelegate>)delegate;

/**
 * Begin the queue, once: disable the idle timer and download the first file.
 * @ghidraAddress 0x42140
 */
- (void)start;

/**
 * Abort the in-flight download and re-enable the idle timer.
 * @ghidraAddress 0x422a0
 */
- (void)cancel;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
