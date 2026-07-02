//
//  StoreDownloadTask.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreDownloadTask.h"

@implementation StoreDownloadTask

// fileURL @ 0x42854 / filePath @ 0x42864 are the synthesized property accessors.
- (instancetype)initWithFileURL:(NSString *)fileURL filePath:(NSString *)filePath {
    if ((self = [super init])) {
        _fileURL = [fileURL retain];
        _filePath = [filePath retain];
    }
    return self;
}

- (void)dealloc {
    [_fileURL release];
    [_filePath release];
    [super dealloc];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
