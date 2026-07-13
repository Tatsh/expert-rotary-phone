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

// Synthesized: delegate @ 0x57764 (getter) / setDelegate: @ 0x57774 (weak,
// plain assign).
@synthesize delegate = m_Delegate;
// packInfo / downloader use the manual retaining accessors below.

// @ 0x57754 / 0x577a0 — retaining setters for packInfo / downloader
// (objc_setProperty). Sibling accessor stubs read the same ivars:
// setDownloader: also @ 0x57794.
- (void)setPackInfo:(StorePackInfo *)packInfo {
    if (m_PackInfo != packInfo) {
        m_PackInfo = packInfo;
    }
}

// @ 0x57794
- (void)setDownloader:(Downloader *)downloader {
    if (m_Downloader != downloader) {
        m_Downloader = downloader;
    }
}

- (StorePackInfo *)packInfo {
    return m_PackInfo;
} // @ 0x57744
- (Downloader *)downloader {
    return m_Downloader;
} // @ 0x57784

// @ 0x57440
- (instancetype)initWithStorePackInfo:(StorePackInfo *)packInfo {
    if ((self = [super init])) {
        [self setPackInfo:packInfo];
    }
    return self;
}

// @ 0x574f4 — GET the pack's detail JSON.
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
- (void)cancel {
    if (m_Downloader == nil) {
        return;
    }
    [m_Downloader cancel];
    m_Downloader = nil;
}

// @ 0x57690 — Downloader progress callback; forward as a proceed notification.
- (void)downloaderProceed:(Downloader *)downloader {
    if ([m_Delegate respondsToSelector:@selector(storePackInfoDownloaderProceed:)]) {
        [m_Delegate storePackInfoDownloaderProceed:self];
    }
}

// @ 0x575fc — fold the response into the pack, then notify success.
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    [self.packInfo setDictionary:json];
    if ([m_Delegate respondsToSelector:@selector(storePackInfoDownloaderFinished:)]) {
        [m_Delegate storePackInfoDownloaderFinished:self];
    }
    [self setDownloader:nil];
}

// @ 0x576d8
- (void)downloaderError:(Downloader *)downloader {
    if ([m_Delegate respondsToSelector:@selector(storePackInfoDownloaderError:)]) {
        [m_Delegate storePackInfoDownloaderError:self];
    }
    [self setDownloader:nil];
}

// @ 0x57488
- (void)dealloc {
    [self setDelegate:nil];
}

@end
