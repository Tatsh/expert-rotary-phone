//
//  TwitterUtil.m
//  pop'n rhythmin
//
//  See TwitterUtil.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin.
//

#import "TwitterUtil.h"

#import <Social/Social.h>

#import "CommonAlertView.h" // failure alert shown from the completion handler
#import "neEngineBridge.h"  // neSceneManager::rootViewController

// Present the Twitter compose sheet with `text` + optional `image` over the
// app's root view controller. Shared by -tweet and +tweetWithText:image: (the
// binary inlines the same body in both). Ghidra: FUN_00078a4c / FUN_00078bb8.
static void PresentTweet(NSString *text, UIImage *image) {
    UIViewController *root = neSceneManager::rootViewController();
    SLComposeViewController *compose =
        [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
    // @ 0x78b10 / 0x78c70 — the two identical completion blocks the binary
    // inlines into -tweet and +tweetWithText:image: (de-inlined here into the
    // shared PresentTweet). On a non-cancel/non-done result (> 1) it surfaces a
    // "tweet post failed" alert, then always dismisses the compose sheet (which
    // SLComposeViewController would otherwise leave up).
    compose.completionHandler = ^(SLComposeViewControllerResult result) {
      if (result > SLComposeViewControllerResultDone) { // Ghidra: 1 < result
          CommonAlertView *alert =
              [[CommonAlertView alloc] initWithTitle:nil
                                             message:@"ツイートの投稿に失敗しました。"
                                            delegate:nil
                                   cancelButtonTitle:nil
                                   otherButtonTitles:@"OK"];
          [alert show];
      }
      [root dismissViewControllerAnimated:YES completion:nil];
    };
    [compose setInitialText:text];
    if (image != nil) {
        [compose addImage:image];
    }
    [root presentViewController:compose animated:YES completion:nil];
}

@implementation TwitterUtil

// dealloc @ 0x788d0 — ARC-omitted (the recovered body only releases the
// m_Text/m_Img object
//   ivars before calling super; ARC does that automatically).
// setText: @ 0x789a8 / setImage: @ 0x78a08 — synthesized copy/strong setters;
// annotated on
//   the @property declarations in TwitterUtil.h.

// Ghidra: @ 0x78934.
- (instancetype)init {
    return [self initWithText:nil image:nil];
}

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
