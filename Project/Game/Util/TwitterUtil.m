//
//  TwitterUtil.m
//  pop'n rhythmin
//
//  See TwitterUtil.h. Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "TwitterUtil.h"

#import <Social/Social.h>

#import "neEngineBridge.h"   // neSceneManager::rootViewController

// Present the Twitter compose sheet with `text` + optional `image` over the app's root
// view controller. Shared by -tweet and +tweetWithText:image: (the binary inlines the
// same body in both). Ghidra: FUN_00078a4c / FUN_00078bb8.
static void PresentTweet(NSString *text, UIImage *image) {
    UIViewController *root = (__bridge UIViewController *)neSceneManager::rootViewController();
    SLComposeViewController *compose =
        [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
    // The binary installs a completion handler (Ghidra: the DAT_0013208c block) that just
    // dismisses the sheet; SLComposeViewController would otherwise leave it up.
    compose.completionHandler = ^(SLComposeViewControllerResult result) {
        [root dismissViewControllerAnimated:YES completion:nil];
    };
    [compose setInitialText:text];
    if (image != nil) {
        [compose addImage:image];
    }
    [root presentViewController:compose animated:YES completion:nil];
}

@implementation TwitterUtil

// Ghidra: @ 0x78948.
- (instancetype)initWithText:(NSString *)text image:(UIImage *)image {
    self = [super init];
    if (self != nil) {
        self.text = text;
        self.image = image;
    }
    return self;
}

// Ghidra: @ 0x78a4c.
- (void)tweet {
    PresentTweet(self.text, self.image);
}

// Ghidra: @ 0x78bb8.
+ (void)tweetWithText:(NSString *)text image:(UIImage *)image {
    PresentTweet(text, image);
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
