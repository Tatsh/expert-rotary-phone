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

@synthesize delegate = m_Delegate;
// packInfo / downloader use the manual retaining accessors below.

// @ 0x57754 / 0x577a0 — retaining setters for packInfo / downloader.
- (void)setPackInfo:(StorePackInfo *)packInfo {
    if (m_PackInfo != packInfo) {
        m_PackInfo = packInfo;
    }
}

- (void)setDownloader:(Downloader *)downloader {
    if (m_Downloader != downloader) {
        m_Downloader = downloader;
    }
}

- (StorePackInfo *)packInfo   { return m_PackInfo; }
- (Downloader *)downloader    { return m_Downloader; }

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

// @ 0x575b8 — abort an in-flight fetch. Cancels the wrapped Downloader, then drops it
// with -autorelease (the binary uses autorelease here, not the setter's -release, so a
// cancel issued from inside a delegate callback still survives the current cycle).
- (void)cancel {
    if (m_Downloader == nil) {
        return;
    }
    [m_Downloader cancel];
    m_Downloader = nil;
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

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
