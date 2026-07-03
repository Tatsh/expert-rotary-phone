//
//  StoreDownloadTask.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreDownloadTask.h"

@implementation StoreDownloadTask

// Synthesized getters: fileURL @ 0x42854, filePath @ 0x42864, addObject @ 0x42874.
@synthesize fileURL = m_FileURL;
@synthesize filePath = m_FilePath;
@synthesize addObject = m_AddObject;

// @ 0x42700 — copy the source URL and local path (NSString -initWithString:), and
// retain the completion object (nil-safe: stored as nil when none is given).
- (instancetype)initWithURL:(NSString *)url path:(NSString *)path AddObject:(id)object {
    if ((self = [super init])) {
        m_FileURL = [[NSString alloc] initWithString:url];
        m_FilePath = [[NSString alloc] initWithString:path];
        if (object == nil) {
            m_AddObject = nil;
        } else {
            m_AddObject = object;
        }
    }
    return self;
}

// dealloc @ 0x427dc — ARC-omitted (released object ivars only).

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
