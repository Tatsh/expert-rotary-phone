//
//  UINavigationBar+RHHeader.h
//  pop'n rhythmin
//
//  Modern-iOS compatibility helper (not a binary reconstruction). On iOS 13 and
//  later the navigation bar resolves its background through
//  UINavigationBarAppearance, and the legacy -setBackgroundImage:forBarMetrics:
//  is ignored at the transparent scroll edge — which dropped the custom header
//  art on every nav-hosted screen. This category sets the legacy image (for
//  earlier iOS) and mirrors it into the standard, scroll-edge, and
//  compact-scroll-edge appearances so the header shows on every OS version. Use
//  it in place of a bare -setBackgroundImage:forBarMetrics: for a header
//  background image.
//

#import <UIKit/UIKit.h>

@interface UINavigationBar (RHHeader)

/// Set @c image as the bar's header background on every iOS version: the legacy
/// bar-metrics background for iOS 12 and earlier, mirrored into the iOS 13+
/// appearance (opaque background, no shadow line) so it is not dropped at the
/// transparent scroll edge.
- (void)setBackgroundImageModern:(UIImage *)image;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
