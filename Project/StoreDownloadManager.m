//
//  StoreDownloadManager.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreDownloadManager.h"

#import "MusicManager.h"
#import "StoreDownloadTask.h"

@implementation StoreDownloadManager {
    Downloader *m_FileDownloader;   // the in-flight per-file download
    NSArray *m_Tasks;               // StoreDownloadTask list
    NSUInteger m_CurrentIndex;      // task being downloaded
}

// Kick off the queue: keep the screen awake and download the first file.
- (void)startWithTasks:(NSArray *)tasks {
    m_Tasks = [tasks retain];
    m_CurrentIndex = 0;
    UIApplication.sharedApplication.idleTimerDisabled = YES;
    [self downloadCurrentTask];
}

// Fetch the current task's file (its remote fileURL) through a Downloader.
- (void)downloadCurrentTask {
    StoreDownloadTask *task = m_Tasks[m_CurrentIndex];
    m_FileDownloader = [[Downloader alloc]
        initWithURL:[NSURL URLWithString:task.fileURL] delegate:self];
    [m_FileDownloader startDownloading];
    if ([_delegate respondsToSelector:@selector(downloadManagerStartTask:)]) {
        [_delegate performSelector:@selector(downloadManagerStartTask:) withObject:self];
    }
}

// @ 0x42314 — write the finished file to its path; on success mark the music
// library dirty and advance to the next file (or finish); on failure notify.
- (void)downloaderFinished:(Downloader *)downloader {
    NSData *data = [m_FileDownloader getData];
    [m_FileDownloader autorelease];
    m_FileDownloader = nil;

    StoreDownloadTask *task = m_Tasks[m_CurrentIndex];
    BOOL ok = [data writeToFile:task.filePath options:NSDataWritingAtomic error:NULL];
    if (!ok) {
        if ([_delegate respondsToSelector:@selector(downloadManagerFailed:)]) {
            [_delegate performSelector:@selector(downloadManagerFailed:) withObject:self];
        }
        return;
    }

    [[MusicManager getInstance] setMusicDataArrayDirty];
    m_CurrentIndex++;
    if (m_CurrentIndex < m_Tasks.count) {
        [self downloadCurrentTask];
    } else {
        UIApplication.sharedApplication.idleTimerDisabled = NO;
        if ([_delegate respondsToSelector:@selector(downloadManagerCompleted:)]) {
            [_delegate performSelector:@selector(downloadManagerCompleted:) withObject:self];
        }
    }
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
