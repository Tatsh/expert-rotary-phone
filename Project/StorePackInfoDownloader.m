//
//  StorePackInfoDownloader.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StorePackInfoDownloader.h"

#import "StorePackInfo.h"
#import "StoreUtil.h"

@implementation StorePackInfoDownloader

// All three properties are compiler-synthesized. delegate is a plain assign
// (weak) setter (setDelegate: @ 0x57774 does str r2,[self+off]); packInfo and
// downloader are retaining setters (setPackInfo: @ 0x57754 and setDownloader: @
// 0x57794 both tail-call objc_setProperty), i.e. @property(retain). The getters
// (packInfo @ 0x57744, downloader @ 0x57784, delegate @ 0x57764) are plain ivar
// reads.
// @complete
@synthesize packInfo = m_PackInfo;
// @complete
@synthesize downloader = m_Downloader;
// @complete
@synthesize delegate = m_Delegate;

// @ 0x57440
// @complete
- (instancetype)initWithStorePackInfo:(StorePackInfo *)packInfo {
    if ((self = [super init])) {
        [self setPackInfo:packInfo];
    }
    return self;
}

// @ 0x574f4 — GET the pack's detail JSON.
// @complete
- (void)downloadDetail:(BOOL)userOpen {
    NSURL *url = [StoreUtil packInfoURL:m_PackInfo.packID UserOpen:userOpen];
    Downloader *downloader = [[Downloader alloc] initWithURL:url delegate:self];
    [self setDownloader:downloader];
    [downloader startDownloading];
}

// @ 0x575b8 — abort an in-flight fetch. Cancels the wrapped Downloader, then
// drops it with -autorelease (the binary uses autorelease here, not the
// setter's -release, so a cancel issued from inside a delegate callback still
// survives the current cycle).
// @complete
- (void)cancel {
    if (m_Downloader == nil) {
        return;
    }
    [m_Downloader cancel];
    m_Downloader = nil;
}

// @ 0x57690 — Downloader progress callback; forward as a proceed notification.
// @complete
- (void)downloaderProceed:(Downloader *)downloader {
    if ([m_Delegate respondsToSelector:@selector(storePackInfoDownloaderProceed:)]) {
        [m_Delegate storePackInfoDownloaderProceed:self];
    }
}

// @ 0x575fc — fold the response into the pack, then notify success.
// @complete
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    [self.packInfo setDictionary:json];
    if ([m_Delegate respondsToSelector:@selector(storePackInfoDownloaderFinished:)]) {
        [m_Delegate storePackInfoDownloaderFinished:self];
    }
    [self setDownloader:nil];
}

// @ 0x576d8
// @complete
- (void)downloaderError:(Downloader *)downloader {
    if ([m_Delegate respondsToSelector:@selector(storePackInfoDownloaderError:)]) {
        [m_Delegate storePackInfoDownloaderError:self];
    }
    [self setDownloader:nil];
}

// @ 0x57488 — the binary nils delegate, packInfo, and downloader (via their
// setters) then calls [super dealloc]. Under ARC the retaining packInfo and
// downloader ivars are released automatically and the weak delegate auto-nils,
// so only the (harmless) explicit delegate teardown is kept.
// @complete
- (void)dealloc {
    [self setDelegate:nil];
}

@end
