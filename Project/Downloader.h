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

// Caller-attached context, echoed back to the delegate to correlate a response
// with its originating request (e.g. PurchaseManager attaches the transaction
// being verified). Synthesized atomic-retain accessors (backing ivar m_AdditionalData):
// getter @ 0x62afc (objc_getProperty), setter @ 0x62b10 (objc_setProperty).
@property (retain) id addData;

// GET. Ghidra: initWithURL:delegate: @ 0x620f4.
- (instancetype)initWithURL:(NSURL *)url delegate:(id<DownloaderDelegate>)delegate;

// POST `body` with the given Content-Type. Ghidra: initWithURL:delegate:Post:ContextType:
// @ 0x6224c.
- (instancetype)initWithURL:(NSURL *)url delegate:(id<DownloaderDelegate>)delegate
                       Post:(NSData *)body ContextType:(NSString *)contentType;

// Kick off the request (records the start time). Ghidra: @ 0x623f0.
- (void)startDownloading;

// Abort an in-flight request: drop the delegate (so no late callbacks fire), cancel +
// release the NSURLConnection, and free the response buffer. Ghidra: @ 0x6249c.
- (void)cancel;

// The raw buffered response bytes (e.g. an audio preview clip). Ghidra: @ 0x62938.
- (NSData *)getData;

// Parse the buffered response as JSON — NSJSONSerialization when available, else the
// bundled TouchJSON category. Ghidra: @ 0x62948.
- (NSDictionary *)getDataInJSON;

// Bytes buffered so far. Ghidra: @ 0x62888.
- (NSUInteger)currentSize;

// Buffered bytes / expected content length (0..1), or 0 when the length is unknown.
// Ghidra: @ 0x628a8.
- (float)currentProgress;

// Time interval relative to the download start (see .m). Ghidra: @ 0x629bc.
- (NSTimeInterval)getProgressSec;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
