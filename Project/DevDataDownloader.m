//
//  DevDataDownloader.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "DevDataDownloader.h"
#import "AppDelegate.h"

// Lazily-created shared instance (Ghidra global g_pDevDataDownloaderInstance).
static DevDataDownloader *s_instance = nil;

@implementation DevDataDownloader

// delegate / setDelegate: @ 0x8ee00 / 0x8ee10, isOld / setIsOld: @ 0x8ee20 / 0x8ee38.
@synthesize delegate = m_Delegate;
@synthesize isOld = m_IsOld;

// +[DevDataDownloader getInstance]  @ 0x8e894 — shared instance; resets isOld to NO on every
// access (as in the binary).
+ (instancetype)getInstance {
    if (s_instance == nil) {
        s_instance = [[DevDataDownloader alloc] init];
    }
    s_instance.isOld = NO;
    return s_instance;
}

// @ 0x8e984 — build the Downloader for a dev-data file and kick it off.
- (BOOL)startDownload:(NSString *)title file:(NSString *)fileName {
    isAcv = [title hasPrefix:@"acv_"];
    if (m_Downloader != nil) {
        return NO;
    }
    NSString *path = [NSString stringWithFormat:(m_IsOld ? @"/apr/dev_data_old/%@/%@"
                                                         : @"/apr/dev_data/%@/%@"),
                                                title, fileName];
    NSURL *url = [[NSURL alloc] initWithScheme:@"http" host:@"dev.apr.konaminet.jp" path:path];
    m_Downloader = [[Downloader alloc] initWithURL:url delegate:self];
    m_Title = title;
    m_FileName = fileName;
    [m_Downloader startDownloading];
    return YES;
}

// @ 0x8eb1c — write the fetched bytes into Caches/<devdata|acvdevdata>/<title>/<file>.
- (void)downloaderFinished:(Downloader *)downloader {
    // drop the in-flight request
    m_Downloader = nil;

    NSString *dir = [NSString stringWithFormat:(isAcv ? @"%@/acvdevdata" : @"%@/devdata"),
                                               [AppDelegate appCachesDirectory]];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;

    if (![fm fileExistsAtPath:dir]) {
        error = nil;
        if (![fm createDirectoryAtPath:dir withIntermediateDirectories:YES
                            attributes:nil error:&error]) {
            [m_Delegate devDownloadFailed:[NSString stringWithFormat:@"createDirError:%@", error]];
            return;
        }
    }

    NSString *titleDir = [NSString stringWithFormat:@"%@/%@", dir, m_Title];
    if (![fm fileExistsAtPath:titleDir]) {
        error = nil;
        if (![fm createDirectoryAtPath:titleDir withIntermediateDirectories:YES
                            attributes:nil error:&error]) {
            [m_Delegate devDownloadFailed:[NSString stringWithFormat:@"createDirError:%@", error]];
            return;
        }
    }

    NSString *filePath = [NSString stringWithFormat:@"%@/%@", titleDir, m_FileName];
    if ([[downloader getData] writeToFile:filePath atomically:YES]) {
        [m_Delegate devDownloadSucceeded:m_FileName];
    } else {
        [m_Delegate devDownloadFailed:[NSString stringWithFormat:@"writeToFileError:%@", filePath]];
    }
}

// @ 0x8ed78 — progress; nothing to do.
- (void)downloaderProceed:(Downloader *)downloader {
}

// @ 0x8ed7c — drop the request and report the failure.
- (void)downloaderError:(Downloader *)downloader {
    m_Downloader = nil;
    [m_Delegate devDownloadFailed:[NSString stringWithFormat:@"downloaderError:%@", m_FileName]];
}

// @ 0x8e8ec — abort any in-flight request on teardown.
- (void)dealloc {
    [m_Downloader cancel];
    m_Downloader = nil;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
