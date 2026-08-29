/**
 * @file
 * A one-shot HTTP request helper.
 *
 * It wraps an NSURLConnection, buffers the response, attaches the app's User-Agent and
 * Accept-Language headers, and notifies its delegate on progress, completion, and failure. The
 * whole app's networking (DownloadMain, store, friend, recommend) goes through this.
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (Downloader @
 * 0x620f4..0x62948).
 */

#import <Foundation/Foundation.h>

@class Downloader;

/**
 * Receives a Downloader's progress, completion and failure notices.
 */
@protocol DownloaderDelegate <NSObject>
@optional
/**
 * A data chunk arrived.
 * @param downloader The request that made progress.
 * @ghidraAddress 0x6267c
 */
- (void)downloaderProceed:(Downloader *)downloader;
/**
 * The request completed successfully.
 * @param downloader The finished request.
 * @ghidraAddress 0x627f4
 */
- (void)downloaderFinished:(Downloader *)downloader;
/**
 * The request failed.
 * @param downloader The failed request.
 * @ghidraAddress 0x6273c
 */
- (void)downloaderError:(Downloader *)downloader;
@end

/**
 * A one-shot HTTP request helper wrapping an NSURLConnection; every network call in the app
 * goes through it.
 */
@interface Downloader : NSObject

/** Caller-attached context, echoed back to the delegate to correlate a response with its
 * originating request — PurchaseManager, for example, attaches the transaction being verified.
 * The accessors are atomic retain over the m_AdditionalData ivar. Getter @ 0x62afc, setter @
 * 0x62b10. */
@property(retain) id addData;

/**
 * Build a GET request.
 * @param url The URL to fetch.
 * @param delegate The delegate to notify.
 * @return The initialised request.
 * @ghidraAddress 0x620f4
 */
- (instancetype)initWithURL:(NSURL *)url delegate:(id<DownloaderDelegate>)delegate;

/**
 * Build a POST request.
 * @param url The URL to post to.
 * @param delegate The delegate to notify.
 * @param body The request body.
 * @param contentType The body's Content-Type.
 * @return The initialised request.
 * @ghidraAddress 0x6224c
 */
- (instancetype)initWithURL:(NSURL *)url
                   delegate:(id<DownloaderDelegate>)delegate
                       Post:(NSData *)body
                ContextType:(NSString *)contentType;

/**
 * Kick off the request, recording the start time.
 * @ghidraAddress 0x623f0
 */
- (void)startDownloading;

/**
 * Abort an in-flight request: drop the delegate so no late callbacks fire, cancel and
 * release the NSURLConnection, and free the response buffer.
 * @ghidraAddress 0x6249c
 */
- (void)cancel;

/**
 * The raw buffered response bytes, such as an audio preview clip.
 * @return The buffered bytes.
 * @ghidraAddress 0x62938
 */
- (NSData *)getData;

/**
 * Parse the buffered response as JSON, using NSJSONSerialization when available and the
 * bundled TouchJSON category otherwise.
 * @return The parsed object, or nil when the body is not valid JSON.
 * @ghidraAddress 0x62948
 */
- (NSDictionary *)getDataInJSON;

/**
 * How many bytes have been buffered so far.
 * @return The buffered byte count.
 * @ghidraAddress 0x62888
 */
- (NSUInteger)currentSize;

/**
 * Buffered bytes as a fraction of the expected content length.
 * @return A value in [0, 1], or 0 when the length is unknown.
 * @ghidraAddress 0x628a8
 */
- (float)currentProgress;

/**
 * How long the request has been running.
 * @return The interval since the download started.
 * @ghidraAddress 0x629bc
 */
- (NSTimeInterval)getProgressSec;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
