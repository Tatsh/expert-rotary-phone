//
//  CommonAlertView.h
//  pop'n rhythmin
//
//  A custom modal alert (styled replacement for UIAlertView, used ~99 places).
//  A gradient-backed rounded card with a message text view, an optional title,
//  and up to two buttons (cancel / other), shown over the root scene view with
//  an open animation. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin.
//

#import <UIKit/UIKit.h>

@class CommonAlertView;

@protocol CommonAlertViewDelegate <NSObject>
// index 0 = cancel button, 1 = other button.
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index;
@end

@interface CommonAlertView : UIView

// UIAlertView-shaped initializer. Ghidra: @ 0x4a350
- (instancetype)initWithTitle:(NSString *)title
                      message:(NSString *)message
                     delegate:(id<CommonAlertViewDelegate>)delegate
            cancelButtonTitle:(NSString *)cancelButtonTitle
            otherButtonTitles:(NSString *)otherButtonTitles;

- (void)show;             // @ 0x4b4cc — add over the root view + open animation
- (BOOL)isVisible;        // @ 0x4bb9c — !self.isHidden

// Atomic copy properties (objc_getProperty/objc_setProperty, atomic flag set).
@property (copy) NSString *title;      // getter @ 0x4bbc0, setter @ 0x4bbd4
@property (copy) NSString *message;    // getter @ 0x4bbe4, setter @ 0x4bbf8

// Atomic assign (unsafe_unretained) — plain barrier'd pointer store, not weak.
@property (assign) id<CommonAlertViewDelegate> delegate;  // getter @ 0x4bc08, setter @ 0x4bc1c

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
