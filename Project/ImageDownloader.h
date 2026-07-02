//
//  ImageDownloader.h
//  pop'n rhythmin
//
//  Lazily loads one remote image for a table-view cell: it downloads over its own
//  NSURLConnection, decodes the result as a (Retina-aware) UIImage, and calls back
//  with the cell's index path so the table can refresh just that row. Reconstructed
//  from Ghidra project rb420, program PopnRhythmin (the connection delegate methods
//  @ 0x5a854/0x5a8e0/0x5a880, cancelDownload @ 0x5a724).
//

#import <UIKit/UIKit.h>

@class ImageDownloader;

@protocol ImageDownloaderDelegate <NSObject>
@optional
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath;      // 0x5a8e0
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath; // 0x5a880
@end

@interface ImageDownloader : NSObject

@property (nonatomic, assign) id<ImageDownloaderDelegate> delegate;
@property (nonatomic, retain) NSURLConnection *imageConnection;   // in-flight connection
@property (nonatomic, retain) NSMutableData *activeDownload;      // received bytes
@property (nonatomic, retain) UIImage *downloadedImage;          // decoded result
@property (nonatomic, retain) NSIndexPath *indexPathInTableView; // the row to refresh

- (void)startDownloadAtURL:(NSURL *)url;   // open the connection
- (void)cancelDownload;                    // @ 0x5a724

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
