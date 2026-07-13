//
//  StoreDownloadTask.h
//  pop'n rhythmin
//
//  One file in a store download: its remote source URL, local destination path,
//  and an arbitrary object to hand back / queue when the download completes.
//  Consumed by StoreDownloadManager. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin (initWithURL:path:AddObject: @ 0x42700, dealloc @
//  0x427dc, and the synthesized getters fileURL @ 0x42854, filePath @ 0x42864,
//  addObject @ 0x42874).
//

#import <Foundation/Foundation.h>

@interface StoreDownloadTask : NSObject {
    NSString *m_FileURL;  // remote source
    NSString *m_FilePath; // local destination
    id m_AddObject;       // object queued/handed back on completion
}

@property(nonatomic, readonly) NSString *fileURL;  // m_FileURL, getter @ 0x42854
@property(nonatomic, readonly) NSString *filePath; // m_FilePath, getter @ 0x42864
@property(nonatomic, readonly) id addObject;       // m_AddObject, getter @ 0x42874

- (instancetype)initWithURL:(NSString *)url path:(NSString *)path AddObject:(id)object;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
