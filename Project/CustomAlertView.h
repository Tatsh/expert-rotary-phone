/**
 * @file
 * @brief A second custom modal alert, the sibling of CommonAlertView.
 *
 * It is built around a fixed piece of background art ("info_bg" or "gift_bg") rather than a drawn
 * gradient card. It hangs a title UILabel, a display-only CustomTextView message, and up to two
 * image-backed buttons (yes and no) off that background image view, then shows and hides itself
 * with a selectable open and close animation (fade or scale bounce). The host installs it into a
 * passed view, or the root scene view, and receives the button result through a weak delegate.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 *
 * On the superclass: the binary builds `self` with -[UIImageView initWithFrame:], tears it down
 * with -[UIImageView dealloc], and explicitly re-enables userInteraction (which UIImageView
 * disables by default), so the recovered superclass is UIImageView, itself a UIView subclass, and
 * it is reconstructed as such.
 */

#import <UIKit/UIKit.h>

@class CustomAlertView;

/**
 * @brief The background-art style, which drives the image and the label and button layout.
 */
typedef NS_ENUM(NSInteger, CustomAlertViewType) {
    CustomAlertViewTypeInfo = 0, /**< The "info_bg" background. */
    CustomAlertViewTypeGift = 1, /**< The "gift_bg" background. */
};

/**
 * @brief The open and close animation style, set via -setOpenAnimeType: and -setCloseAnimeType:.
 */
typedef NS_ENUM(NSInteger, CustomAlertViewAnimeType) {
    CustomAlertViewAnimeTypeFade = 0,  /**< An alpha fade. */
    CustomAlertViewAnimeTypeScale = 1, /**< A scale bounce. */
};

/**
 * @brief Receives the alert's button taps.
 */
@protocol CustomAlertViewDelegate <NSObject>
/**
 * @brief A button was tapped.
 * @param alertView The alert that was dismissed.
 * @param index 0 for the no or cancel button, 1 for the yes or other button.
 */
- (void)customAlertView:(CustomAlertView *)alertView clickedButtonAtIndex:(NSInteger)index;
@end

/**
 * @brief A modal alert built around a fixed piece of background art rather than a drawn gradient
 * card.
 */
@interface CustomAlertView : UIImageView

/** The button-tap delegate. Getter @ 0x27b8c, setter @ 0x27b9c. */
@property(nonatomic, weak) id<CustomAlertViewDelegate> delegate;

/**
 * @brief Install the alert into the root scene view, centred on it.
 * @param type The background-art style.
 * @param title The alert title.
 * @param message The alert body.
 * @param cancelButtonTitle The no or cancel button's title.
 * @param otherButtonTitle The yes or other button's title, or nil for a one-button alert.
 * @return The initialised alert.
 * @ghidraAddress 0x269c4
 */
- (instancetype)initWithType:(CustomAlertViewType)type
                       title:(NSString *)title
                     message:(NSString *)message
           cancelButtonTitle:(NSString *)cancelButtonTitle
            otherButtonTitle:(NSString *)otherButtonTitle;

/**
 * @brief Install the alert into @p view, centred on it.
 * @param view The host view.
 * @param type The background-art style.
 * @param title The alert title.
 * @param message The alert body.
 * @param cancelButtonTitle The no or cancel button's title.
 * @param otherButtonTitle The yes or other button's title, or nil for a one-button alert.
 * @return The initialised alert.
 * @ghidraAddress 0x26a60
 */
- (instancetype)initWithView:(UIView *)view
                        type:(CustomAlertViewType)type
                       title:(NSString *)title
                     message:(NSString *)message
           cancelButtonTitle:(NSString *)cancelButtonTitle
            otherButtonTitle:(NSString *)otherButtonTitle;

/**
 * @brief The designated initialiser.
 * @param view The host view.
 * @param center Where to place the alert; CGPointZero uses the host view's centre.
 * @param type The background-art style.
 * @param title The alert title.
 * @param message The alert body.
 * @param cancelButtonTitle The no or cancel button's title.
 * @param otherButtonTitle The yes or other button's title, or nil for a one-button alert.
 * @return The initialised alert.
 * @ghidraAddress 0x26abc
 */
- (instancetype)initWithView:(UIView *)view
                      center:(CGPoint)center
                        type:(CustomAlertViewType)type
                       title:(NSString *)title
                     message:(NSString *)message
           cancelButtonTitle:(NSString *)cancelButtonTitle
            otherButtonTitle:(NSString *)otherButtonTitle;

/**
 * @brief Reveal the alert and run its open animation.
 * @ghidraAddress 0x274fc
 */
- (void)show;
/**
 * @brief Dismiss the alert and run its close animation.
 * @ghidraAddress 0x277b8
 */
- (void)removeView;

// Runtime restyling of the already-built title and message widgets.

/**
 * @brief Restyle the title colour.
 * @param color The new title colour.
 * @ghidraAddress 0x268ac
 */
- (void)setTitleColor:(UIColor *)color;
/**
 * @brief Restyle the message colour.
 * @param color The new message colour.
 * @ghidraAddress 0x268cc
 */
- (void)setTextColor:(UIColor *)color;
/**
 * @brief Restyle the title font size.
 * @param size The new point size.
 * @ghidraAddress 0x268ec
 */
- (void)setTitleFontSize:(CGFloat)size;
/**
 * @brief Restyle the message font size.
 * @param size The new point size.
 * @ghidraAddress 0x26940
 */
- (void)setTextFontSize:(CGFloat)size;

/**
 * @brief Select the open animation.
 * @param type The animation style; clamped to 0..1.
 * @ghidraAddress 0x26994
 */
- (void)setOpenAnimeType:(CustomAlertViewAnimeType)type;
/**
 * @brief Select the close animation.
 * @param type The animation style; clamped to 0..1.
 * @ghidraAddress 0x269ac
 */
- (void)setCloseAnimeType:(CustomAlertViewAnimeType)type;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
