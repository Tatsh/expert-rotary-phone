//
//  FriendListDetailChara.h
//  pop'n rhythmin
//
//  The character/skill info popup shown when tapping the portrait inside a FriendListDetail.
//  A framed "skill card" over a window backdrop: the friend's chara portrait, a rounded card
//  carrying the chara icon, chara name, a speech bubble with the skill name, the skill
//  description, and the sugoroku chara art. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initWithFrame:friendData: @ 0xbac58). Built in FriendListDetailChara.mm.
//

#import <UIKit/UIKit.h>

@interface FriendListDetailChara : UIImageView

// `friendData` is an NSValue-wrapped FriendListData; only its charaId is used (to look up the
// character's name, skill and art). `frame` positions the popup over the tapped portrait.
- (instancetype)initWithFrame:(CGRect)frame friendData:(NSValue *)friendData;

// Fade the popup in (0.3s) / out (0.3s, then remove from its superview).
- (void)startOpenAnimation;
- (void)startCloseAnimation;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
