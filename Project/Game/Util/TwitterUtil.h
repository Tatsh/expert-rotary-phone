//
//  TwitterUtil.h
//  pop'n rhythmin
//
//  The result screen's "tweet this score" helper. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin (initWithText:image: @ 0x78948, tweet @ 0x78a4c,
//  tweetWithText:image: @ 0x78bb8). It is a UIViewController subclass only so it can
//  be wired as a UIButton target; the actual share is an SLComposeViewController
//  (Social.framework) for the Twitter service, presented over the root view controller.
//

#import <UIKit/UIKit.h>

@interface TwitterUtil : UIViewController

// The pending tweet body + attached image (Ghidra ivars m_Text / m_Img).
@property (nonatomic, retain) NSString *text;
@property (nonatomic, retain) UIImage *image;

// Retain the text + image to tweet later (the result screen's share button owns one).
// Ghidra: -[TwitterUtil initWithText:image:] @ 0x78948.
- (instancetype)initWithText:(NSString *)text image:(UIImage *)image;

// Present the Twitter compose sheet with this instance's text + image (the button's
// action selector). Ghidra: -[TwitterUtil tweet] @ 0x78a4c.
- (void)tweet;

// One-shot: present the Twitter compose sheet with the given text + image. Ghidra:
// -[TwitterUtil tweetWithText:image:] @ 0x78bb8.
+ (void)tweetWithText:(NSString *)text image:(UIImage *)image;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
