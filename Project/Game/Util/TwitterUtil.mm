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
// Verified against the completion block @ 0x78b10: `cmp result,#2; bcc` skips
// the alert for result < 2 (fires it for result > Done), building the CommonAlert
// with title nil / cancel nil / other "OK", then always re-fetches the root VC
// (bl 0xb194) and tail-calls dismissViewControllerAnimated:1 completion:nil.
static void PresentTweet(NSString *text, UIImage *image) {
#if !defined(__IPHONE_11_0) || __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_11_0
    UIViewController *root = neSceneManager::rootViewController();
    SLComposeViewController *compose =
        [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
    // @ 0x78b10 / 0x78c70 — the two identical completion blocks the binary
    // inlines into -tweet and +tweetWithText:image: (de-inlined here into the
    // shared PresentTweet). On a non-cancel/non-done result (> 1) it surfaces a
    // "tweet post failed" alert, then always dismisses the compose sheet (which
    // SLComposeViewController would otherwise leave up). Verified against the block
    // body @ 0x78b10: `cmp result,#2; bcc` skips the alert for result < 2 (so it
    // fires for result > Done); then it always re-fetches the root VC and
    // dismisses. The binary re-fetches rather than capturing `root`; equivalent
    // since it is a stable singleton accessor.
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
#else
    // The Social-framework Twitter composer (SLServiceTypeTwitter) was removed
    // in iOS 11, so this is a no-op when built against a modern SDK.
    (void)text;
    static_cast<void>(image);
    return;
#endif
}

@implementation TwitterUtil

// dealloc @ 0x788d0 — ARC-omitted (the recovered body only releases the
// m_Text/m_Img object
//   ivars before calling super; ARC does that automatically).
// setText: @ 0x789a8 / setImage: @ 0x78a08 — synthesized copy/strong setters;
// annotated on
//   the @property declarations in TwitterUtil.h.

// Ghidra: @ 0x78934 — verified: tail-call initWithText:nil image:nil.
- (instancetype)init {
    return [self initWithText:nil image:nil];
}

// Ghidra: @ 0x78948 — verified: [super init]; on non-nil, self.text = text;
// self.image = image (property setters).
- (instancetype)initWithText:(NSString *)text image:(UIImage *)image {
    self = [super init];
    if (self != nil) {
        self.text = text;
        self.image = image;
    }
    return self;
}

// Ghidra: @ 0x78a4c — verified: rootViewController; compose for Twitter;
// setCompletionHandler: (block @ 0x78b10); setInitialText:self.text; addImage:
// only if self.image != nil; presentViewController animated:1 completion:nil.
- (void)tweet {
    PresentTweet(self.text, self.image);
}

// Ghidra: @ 0x78bb8 — verified: identical body to -tweet with text/image args
// (distinct block instance @ 0x78c70, same body).
+ (void)tweetWithText:(NSString *)text image:(UIImage *)image {
    PresentTweet(text, image);
}

@end
