//
//  StoreDownloadManager.h
//  pop'n rhythmin
//
//  Downloads a list of purchased/updated files sequentially, writing each to its
//  destination path and marking the music library dirty, then reports progress to
//  its delegate. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithTasks:delegate: @ 0x41fec, start @ 0x42140, downloaderFinished: @ 0x42314).
//

#import <Foundation/Foundation.h>

#import "Downloader.h"

@class StoreDownloadManager;

@protocol StoreDownloadManagerDelegate <NSObject>
@optional
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager;  // next file started
- (void)downloadManagerProceed:(StoreDownloadManager *)manager;    // download progressed
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager;  // all files done
- (void)downloadManagerFailed:(StoreDownloadManager *)manager;     // a download/write failed
@end

@interface StoreDownloadManager : NSObject <DownloaderDelegate>

@property (nonatomic, assign) id<StoreDownloadManagerDelegate> delegate;

// The (immutable copy of the) task list this manager was created with. @ 0x426f0
@property (nonatomic, readonly) NSArray *tasks;
// Index of the file currently downloading. @ 0x426e0
@property (nonatomic, readonly) NSUInteger currentIndex;
// Number of files in the queue (tasks.count). @ 0x42120
@property (nonatomic, readonly) NSUInteger numTasks;
// Progress (0..1) of the file currently downloading. @ 0x42090
@property (nonatomic, readonly) float currentProgress;
// Overall progress (0..1): (currentIndex + currentProgress) / numTasks. @ 0x420b0
@property (nonatomic, readonly) float overallProgress;

// Create with a list of StoreDownloadTask (each a fileURL + filePath); returns nil
// when `tasks` is nil. The list is copied. @ 0x41fec
- (instancetype)initWithTasks:(NSArray *)tasks
                     delegate:(id<StoreDownloadManagerDelegate>)delegate;

// Begin the queue (once): disable the idle timer and download the first file. @ 0x42140
- (void)start;

// Abort the in-flight download and re-enable the idle timer. @ 0x422a0
- (void)cancel;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
