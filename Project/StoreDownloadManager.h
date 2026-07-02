//
//  StoreDownloadManager.h
//  pop'n rhythmin
//
//  Downloads a list of purchased/updated files sequentially, writing each to its
//  destination path and marking the music library dirty, then reports progress to
//  its delegate. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (downloaderFinished: @ 0x42314).
//

#import <Foundation/Foundation.h>

#import "Downloader.h"

@class StoreDownloadManager;

@protocol StoreDownloadManagerDelegate <NSObject>
@optional
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager;  // next file started
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager;  // all files done
- (void)downloadManagerFailed:(StoreDownloadManager *)manager;     // a write failed
@end

@interface StoreDownloadManager : NSObject <DownloaderDelegate>

@property (nonatomic, assign) id<StoreDownloadManagerDelegate> delegate;

// Begin downloading `tasks` (each a StoreDownloadTask with a fileURL + filePath),
// keeping the idle timer disabled until the queue finishes.
- (void)startWithTasks:(NSArray *)tasks;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
