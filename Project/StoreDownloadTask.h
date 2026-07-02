//
//  StoreDownloadTask.h
//  pop'n rhythmin
//
//  One file in a store download: its remote source URL and local destination path.
//  Consumed by StoreDownloadManager. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (fileURL @ 0x42854, filePath @ 0x42864).
//

#import <Foundation/Foundation.h>

@interface StoreDownloadTask : NSObject

@property (nonatomic, retain) NSString *fileURL;    // remote source (m_FileURL)
@property (nonatomic, retain) NSString *filePath;   // local destination (m_FilePath)

- (instancetype)initWithFileURL:(NSString *)fileURL filePath:(NSString *)filePath;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
