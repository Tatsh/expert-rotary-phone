//
//  TwitterUtil.h
//  pop'n rhythmin
//
//  The result screen's "tweet this score" helper. Reconstructed from Ghidra
//  project rb420, program PopnRhythmin (initWithText:image: @ 0x78948, tweet @
//  0x78a4c, tweetWithText:image: @ 0x78bb8). It is a UIViewController subclass
//  only so it can be wired as a UIButton target; the actual share is an
//  SLComposeViewController (Social.framework) for the Twitter service,
//  presented over the root view controller.
//

#import <UIKit/UIKit.h>

@interface TwitterUtil : UIViewController
/**
 * @brief The text to be tweeted.
 * @note The text is copied by the setter.
 */
@property(nonatomic, copy) NSString *text;
/**
 * @brief The image to be attached to the tweet.
 * @note The image is retained by the TwitterUtil instance.
 */
@property(nonatomic, strong) UIImage *image;
/**
 * @brief Initializes a TwitterUtil instance with no text or image.
 * @return An initialized TwitterUtil instance.
 * @ghidraAddress 0x78934
 */
- (instancetype)init;
/**
 * @brief Initializes a TwitterUtil instance with the given text and image.
 * @param text The text to be tweeted.
 * @param image The image to be attached to the tweet.
 * @return An initialized TwitterUtil instance with the specified text and image.
 * @ghidraAddress 0x78948
 */
- (instancetype)initWithText:(NSString *)text image:(UIImage *)image;
/**
 * @brief Presents the Twitter compose sheet with the instance's text and image.
 * @note This method is typically called as an action from a UIButton.
 * @ghidraAddress 0x78a4c
 */
- (void)tweet;
/**
 * @brief Presents the Twitter compose sheet with the specified text and image.
 * @param text The text to be tweeted.
 * @param image The image to be attached to the tweet.
 * @ghidraAddress 0x78bb8
 */
+ (void)tweetWithText:(NSString *)text image:(UIImage *)image;
@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
