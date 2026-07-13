//
//  ImageDownloader.h
//  pop'n rhythmin
//
//  Lazily loads one remote image for a table-view cell: it downloads over its
//  own NSURLConnection, decodes the result as a (Retina-aware) UIImage, and
//  calls back with the cell's index path so the table can refresh just that
//  row. Reconstructed from Ghidra project rb420, program PopnRhythmin (the
//  connection delegate methods
//  @ 0x5a854/0x5a8e0/0x5a880, cancelDownload @ 0x5a724).
//

#import <UIKit/UIKit.h>

@class ImageDownloader;

@protocol ImageDownloaderDelegate <NSObject>
@optional
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath; // 0x5a8e0
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader
                       didLoad:(NSIndexPath *)indexPath; // 0x5a880
@end

@interface ImageDownloader : NSObject

@property(nonatomic, assign) id<ImageDownloaderDelegate>
    delegate; // getter @ 0x5ab94 / setter @ 0x5aba4
@property(nonatomic, retain)
    NSString *imageURL; // source URL string, getter @ 0x5ab54 / setter @ 0x5ab64
@property(nonatomic, retain)
    NSURLConnection *imageConnection; // in-flight connection, getter @ 0x5abd4
                                      // / setter @ 0x5abe4
@property(nonatomic, retain)
    NSMutableData *activeDownload; // received bytes, getter @ 0x5abb4 / setter @ 0x5abc4
@property(nonatomic, retain)
    UIImage *downloadedImage; // decoded result, getter @ 0x5abf4 / setter @ 0x5ac04
@property(nonatomic, retain)
    NSIndexPath *indexPathInTableView; // the row to refresh, getter @ 0x5ab74 /
                                       // setter @ 0x5ab84

- (void)startDownload;  // open the connection using imageURL @ 0x5a63c
- (void)cancelDownload; // @ 0x5a724
- (UIImage *)getImage;  // the decoded result @ 0x5a78c

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
