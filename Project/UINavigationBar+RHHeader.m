//
//  UINavigationBar+RHHeader.m
//  pop'n rhythmin
//

#import "UINavigationBar+RHHeader.h"

@implementation UINavigationBar (RHHeader)

- (void)setBackgroundImageModern:(UIImage *)image {
    [self setBackgroundImage:image forBarMetrics:UIBarMetricsDefault];
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundImage = image;
        appearance.shadowColor = UIColor.clearColor;
        self.standardAppearance = appearance;
        self.scrollEdgeAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            self.compactScrollEdgeAppearance = appearance;
        }
    }
}

@end
