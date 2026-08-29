/**
 * @file
 * @brief A small synchronous-style HTTP helper built directly on NSURLConnection.
 *
 * It acts as an async delegate, buffers the response into an NSMutableData, tracks the HTTP
 * status code and the response text encoding (Shift-JIS versus UTF-8), and exposes the decoded
 * body plus a coarse state machine via -status.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin: init @ 0x6a550, get: @ 0x6a58c,
 * post:paramString: @ 0x6a6c4, connection:didReceiveResponse: @ 0x6a8c0,
 * connection:didReceiveData: @ 0x6a978, connection:didFailWithError: @ 0x6a9c8,
 * connectionDidFinishLoading: @ 0x6aa38, receivedString @ 0x6ab60, status @ 0x6ab74, and
 * setStatus: @ 0x6ab88.
 */

#import <Foundation/Foundation.h>

/**
 * @brief The coarse request states observed in the binary, exposed as HttpConn.status.
 */
enum {
    HttpConnStatusReady = 0,    /**< Idle; a new -get: or -post: is allowed. */
    HttpConnStatusRunning = 1,  /**< A request is in flight. */
    HttpConnStatusEncoding = 2, /**< Finished, but the body failed to decode. */
    HttpConnStatusSuccess = 3,  /**< Finished, body decoded, HTTP status below 400. */
    HttpConnStatusError = 4,    /**< The connection failed, or the HTTP status was 400 or above. */
};

/**
 * @brief A simple HTTP request helper that decodes its response body into a string.
 */
@interface HttpConn : NSObject <NSURLConnectionDataDelegate> {
    NSMutableData *receivedData; /**< The response bytes accumulated so far. */
    NSString *receivedString;    /**< The decoded body, set on finish. */
    /** NSShiftJISStringEncoding or NSUTF8StringEncoding. */
    NSStringEncoding encoding;
    NSURLConnection *conn; /**< The active connection. */
    int statusCode;        /**< The HTTP status code from the response. */
    int status;            /**< The coarse state; see the HttpConnStatus values. */
}

/** The decoded body, populated by -connectionDidFinishLoading:. The getter is atomic. Getter @
 * 0x6ab60. */
@property(readonly) NSString *receivedString;
/** The coarse request state. The accessors are atomic, using a DataMemoryBarrier. Getter @
 * 0x6ab74, setter @ 0x6ab88. */
@property(assign) int status;

/**
 * @brief Fire a GET; it logs and returns if a request is already running.
 * @param urlString The URL to fetch.
 * @ghidraAddress 0x6a58c
 */
- (void)get:(NSString *)urlString;

/**
 * @brief Fire a POST with an application/x-www-form-urlencoded body.
 * @param urlString The URL to post to.
 * @param paramString The form-encoded body.
 * @ghidraAddress 0x6a6c4
 */
- (void)post:(NSString *)urlString paramString:(NSString *)paramString;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
