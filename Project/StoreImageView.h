//
//  StoreImageView.h
//  pop'n rhythmin
//
//  A remote-image UIImageView used throughout the store UI (pack jackets,
//  song-row artwork, promotion thumbnails): assign -imageURL then call
//  -startDownloadImage and it fetches the bytes through an ImageDownloader,
//  decodes them into a Retina-aware UIImage, and drops the result into its own
//  -image. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (startDownloadImage @ 0x42884, imageDownloader:didLoad:
//  @ 0x42980, imageDownloaderDidFail:didLoad: @ 0x42a7c, setImageURL: @
//  0x42b30).
//

#import <UIKit/UIKit.h>

#import "ImageDownloader.h"

/**
 * @brief A UIImageView that fetches its image from a URL on demand.
 */
@interface StoreImageView : UIImageView <ImageDownloaderDelegate> {
    NSString *m_ImageURL;               /**< The source URL string. */
    ImageDownloader *m_ImageDownloader; /**< The in-flight fetch; nil when idle. */
}

/** The image source. Set it, then call -startDownloadImage. Setter @ 0x42b30. */
@property(nonatomic, retain) NSString *imageURL;

/**
 * @brief Start the fetch for the current imageURL; a no-op when the URL is unset or a fetch is
 * already running.
 * @ghidraAddress 0x42884
 */
- (void)startDownloadImage;

/**
 * @brief Cancel any in-flight fetch and set the view's image.
 * @param image The image to show, or nil to clear it.
 * @ghidraAddress 0x42928
 */
- (void)unloadImage:(UIImage *)image;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
