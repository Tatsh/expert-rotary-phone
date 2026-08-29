/**
 * @file
 * @brief A lazy loader for one remote image belonging to a table-view cell.
 *
 * It downloads over its own NSURLConnection, decodes the result as a Retina-aware UIImage, and
 * calls back with the cell's index path so the table can refresh just that row. Reconstructed
 * from Ghidra project rb420, program PopnRhythmin (the connection delegate methods @ 0x5a854,
 * 0x5a8e0, and 0x5a880, cancelDownload @ 0x5a724).
 */

#import <UIKit/UIKit.h>

@class ImageDownloader;

/**
 * @brief Receives an ImageDownloader's completion and failure notices.
 */
@protocol ImageDownloaderDelegate <NSObject>
@optional
/**
 * @brief The image finished downloading and decoding.
 * @param downloader The finished downloader.
 * @param indexPath The table row to refresh.
 * @ghidraAddress 0x5a8e0
 */
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath;
/**
 * @brief The image failed to download or decode.
 * @param downloader The failed downloader.
 * @param indexPath The table row that was waiting on it.
 * @ghidraAddress 0x5a880
 */
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath;
@end

/**
 * @brief Fetches and decodes one image for a table row.
 */
@interface ImageDownloader : NSObject

/** The completion delegate. Getter @ 0x5ab94, setter @ 0x5aba4. */
@property(nonatomic, assign) id<ImageDownloaderDelegate> delegate;
/** The source URL string. Getter @ 0x5ab54, setter @ 0x5ab64. */
@property(nonatomic, retain) NSString *imageURL;
/** The in-flight connection. Getter @ 0x5abd4, setter @ 0x5abe4. */
@property(nonatomic, retain) NSURLConnection *imageConnection;
/** The bytes received so far. Getter @ 0x5abb4, setter @ 0x5abc4. */
@property(nonatomic, retain) NSMutableData *activeDownload;
/** The decoded result. Getter @ 0x5abf4, setter @ 0x5ac04. */
@property(nonatomic, retain) UIImage *downloadedImage;
/** The table row to refresh once the image arrives. Getter @ 0x5ab74, setter @ 0x5ab84. */
@property(nonatomic, retain) NSIndexPath *indexPathInTableView;

/**
 * @brief Open the connection using imageURL.
 * @ghidraAddress 0x5a63c
 */
- (void)startDownload;
/**
 * @brief Cancel the in-flight connection.
 * @ghidraAddress 0x5a724
 */
- (void)cancelDownload;
/**
 * @brief The decoded result.
 * @return The image, or nil before the download finishes.
 * @ghidraAddress 0x5a78c
 */
- (UIImage *)getImage;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
