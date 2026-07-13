//
//  CustomAlertView.h
//  pop'n rhythmin
//
//  A second custom modal alert (sibling of CommonAlertView) built around a
//  fixed piece of background art ("info_bg" / "gift_bg") rather than a drawn
//  gradient card. It hangs a title UILabel, a display-only CustomTextView
//  message and up to two image-backed buttons (yes / no) off that background
//  image view, then shows and hides itself with a selectable open/close
//  animation (fade or scale bounce). The host installs it into a passed view
//  (or the root scene view) and receives the button result through a weak
//  delegate.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  NOTE ON SUPERCLASS: the binary builds `self` with -[UIImageView
//  initWithFrame:], tears it down with -[UIImageView dealloc] and explicitly
//  re-enables userInteraction (which UIImageView disables by default), so the
//  recovered superclass is UIImageView (itself a UIView subclass).
//  Reconstructed as such.
//

#import <UIKit/UIKit.h>

@class CustomAlertView;

// Background-art style (drives which image + label/button layout is used).
typedef NS_ENUM(NSInteger, CustomAlertViewType) {
    CustomAlertViewTypeInfo = 0, // "info_bg" background
    CustomAlertViewTypeGift = 1, // "gift_bg" background
};

// Open / close animation style (set via -setOpenAnimeType: /
// -setCloseAnimeType:).
typedef NS_ENUM(NSInteger, CustomAlertViewAnimeType) {
    CustomAlertViewAnimeTypeFade = 0,  // alpha fade
    CustomAlertViewAnimeTypeScale = 1, // scale bounce
};

@protocol CustomAlertViewDelegate <NSObject>
// index 0 = no / cancel button, 1 = yes / other button.
- (void)customAlertView:(CustomAlertView *)alertView clickedButtonAtIndex:(NSInteger)index;
@end

@interface CustomAlertView : UIImageView

// Synthesized accessors: delegate @ 0x27b8c, setDelegate: @ 0x27b9c.
@property(nonatomic, weak) id<CustomAlertViewDelegate> delegate;

// Installs into the root scene view
// (neSceneManager::rootViewController().view), centred on it. Ghidra: @ 0x269c4
- (instancetype)initWithType:(CustomAlertViewType)type
                       title:(NSString *)title
                     message:(NSString *)message
           cancelButtonTitle:(NSString *)cancelButtonTitle
            otherButtonTitle:(NSString *)otherButtonTitle;

// Installs into `view`, centred on it (CGPointZero center -> use view centre).
// Ghidra: @ 0x26a60
- (instancetype)initWithView:(UIView *)view
                        type:(CustomAlertViewType)type
                       title:(NSString *)title
                     message:(NSString *)message
           cancelButtonTitle:(NSString *)cancelButtonTitle
            otherButtonTitle:(NSString *)otherButtonTitle;

// Designated initializer. Ghidra: @ 0x26abc
- (instancetype)initWithView:(UIView *)view
                      center:(CGPoint)center
                        type:(CustomAlertViewType)type
                       title:(NSString *)title
                     message:(NSString *)message
           cancelButtonTitle:(NSString *)cancelButtonTitle
            otherButtonTitle:(NSString *)otherButtonTitle;

- (void)show;       // reveal + open animation.   Ghidra: @ 0x274fc
- (void)removeView; // dismiss + close animation.  Ghidra: @ 0x277b8

// Runtime restyling of the (already-built) title / message widgets.
- (void)setTitleColor:(UIColor *)color; // Ghidra: @ 0x268ac
- (void)setTextColor:(UIColor *)color;  // Ghidra: @ 0x268cc
- (void)setTitleFontSize:(CGFloat)size; // Ghidra: @ 0x268ec
- (void)setTextFontSize:(CGFloat)size;  // Ghidra: @ 0x26940

// Select the open / close animation (clamped to 0..1). Ghidra: @ 0x26994 / @
// 0x269ac
- (void)setOpenAnimeType:(CustomAlertViewAnimeType)type;
- (void)setCloseAnimeType:(CustomAlertViewAnimeType)type;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
