//
//  HttpConn.h
//  pop'n rhythmin
//
//  A small synchronous-style HTTP helper built directly on NSURLConnection (as
//  an async delegate). Buffers the response into an NSMutableData, tracks the
//  HTTP status code and the response text encoding (Shift-JIS vs UTF-8), and
//  exposes the decoded body plus a coarse state machine via -status.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    init @ 0x6a550   get: @ 0x6a58c   post:paramString: @ 0x6a6c4
//    connection:didReceiveResponse: @ 0x6a8c0   connection:didReceiveData: @
//    0x6a978 connection:didFailWithError: @ 0x6a9c8 connectionDidFinishLoading:
//    @ 0x6aa38 receivedString @ 0x6ab60   status @ 0x6ab74   setStatus: @
//    0x6ab88
//

#import <Foundation/Foundation.h>

// -status values observed in the binary.
enum {
    HttpConnStatusReady = 0,    // idle; a new get:/post: is allowed
    HttpConnStatusRunning = 1,  // request in flight
    HttpConnStatusEncoding = 2, // finished but the body failed to decode
    HttpConnStatusSuccess = 3,  // finished, body decoded, HTTP < 400
    HttpConnStatusError = 4,    // connection failed or HTTP >= 400
};

@interface HttpConn : NSObject <NSURLConnectionDataDelegate> {
    NSMutableData *receivedData; // response bytes accumulated so far
    NSString *receivedString;    // decoded body (set on finish)
    NSStringEncoding encoding;   // NSShiftJISStringEncoding or NSUTF8StringEncoding
    NSURLConnection *conn;       // active connection
    int statusCode;              // HTTP status code from the response
    int status;                  // coarse state (see enum above)
}

// getter @ 0x6ab60 (atomic) — decoded body; populated by
// connectionDidFinishLoading:.
@property(readonly) NSString *receivedString;
// getter @ 0x6ab74 / setter @ 0x6ab88 (atomic, DataMemoryBarrier).
@property(assign) int status;

// Fire a GET. No-op (logs) if a request is already running. Ghidra: @ 0x6a58c.
- (void)get:(NSString *)urlString;

// Fire a POST with an application/x-www-form-urlencoded body. Ghidra: @
// 0x6a6c4.
- (void)post:(NSString *)urlString paramString:(NSString *)paramString;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
