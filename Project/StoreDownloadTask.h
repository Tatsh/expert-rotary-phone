/**
 * @file
 * One file in a store download.
 *
 * It carries the remote source URL, the local destination path, and an arbitrary object to hand
 * back or queue when the download completes. StoreDownloadManager consumes it. Reconstructed from
 * Ghidra project rb420, program PopnRhythmin (initWithURL:path:AddObject: @ 0x42700, dealloc @
 * 0x427dc, and the synthesised getters fileURL @ 0x42854, filePath @ 0x42864, and addObject @
 * 0x42874).
 */

#import <Foundation/Foundation.h>

/**
 * One entry of a StoreDownloadManager queue: a remote source, a local destination and a
 * caller-supplied context object.
 */
@interface StoreDownloadTask : NSObject {
    NSString *m_FileURL;  /**< The remote source. */
    NSString *m_FilePath; /**< The local destination. */
    id m_AddObject;       /**< The object queued and handed back on completion. */
}

/** The remote source. Getter @ 0x42854. */
@property(nonatomic, readonly) NSString *fileURL;
/** The local destination. Getter @ 0x42864. */
@property(nonatomic, readonly) NSString *filePath;
/** The object handed back on completion. Getter @ 0x42874. */
@property(nonatomic, readonly) id addObject;

/**
 * Build a download task.
 * @param url The remote source.
 * @param path The local destination.
 * @param object The context object to hand back on completion.
 * @return The initialised task.
 */
- (instancetype)initWithURL:(NSString *)url path:(NSString *)path AddObject:(id)object;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
