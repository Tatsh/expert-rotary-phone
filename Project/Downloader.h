//
//  Downloader.h
//  pop'n rhythmin
//
//  A one-shot HTTP request helper: wraps an NSURLConnection, buffers the response,
//  attaches the app's User-Agent + Accept-Language headers, and notifies its
//  delegate on progress / completion / failure. The whole app's networking
//  (DownloadMain, store, friend, recommend) goes through this. Reconstructed from
//  Ghidra project rb420, program PopnRhythmin (Downloader @ 0x620f4..0x62948).
//

#import <Foundation/Foundation.h>

@class Downloader;

@protocol DownloaderDelegate <NSObject>
@optional
- (void)downloaderProceed:(Downloader *)downloader;   // @ 0x6267c (each data chunk)
- (void)downloaderFinished:(Downloader *)downloader;  // @ 0x627f4 (success)
- (void)downloaderError:(Downloader *)downloader;     // @ 0x6273c (failure)
@end

@interface Downloader : NSObject

// GET. Ghidra: initWithURL:delegate: @ 0x620f4.
- (instancetype)initWithURL:(NSURL *)url delegate:(id<DownloaderDelegate>)delegate;

// POST `body` with the given Content-Type. Ghidra: initWithURL:delegate:Post:ContextType:
// @ 0x6224c.
- (instancetype)initWithURL:(NSURL *)url delegate:(id<DownloaderDelegate>)delegate
                       Post:(NSData *)body ContextType:(NSString *)contentType;

// Kick off the request (records the start time). Ghidra: @ 0x623f0.
- (void)startDownloading;

// Parse the buffered response as JSON — NSJSONSerialization when available, else the
// bundled TouchJSON category. Ghidra: @ 0x62948.
- (NSDictionary *)getDataInJSON;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
