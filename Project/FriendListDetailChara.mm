//
//  FriendListDetailChara.mm
//  pop'n rhythmin
//
//  See FriendListDetailChara.h. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithFrame:friendData: @ 0xbac58, dealloc @ 0xbbb18, start/endOpenAnimation @ 0xbbb48/0xbbc18,
//  start/endCloseAnimation @ 0xbbc30/0xbbd00). Objective-C++ for gCharaManager / GetSkillDataStruct
//  and the neSceneManager device check.
//
//  Honesty note: initWithFrame:friendData: is laid out with a global scale factor (1.0 on phone,
//  2.0 on iPad) applied to every dimension via NEON vector multiplies. Ghidra spilled most of the
//  CGRect arguments across NEON registers, so the exact per-view frame ORIGINS are only partially
//  recoverable; the recovered layout constants (positions/sizes) and, crucially, the parent-relative
//  re-centring (each element is setCenter'd against its parent's frame) are reproduced faithfully,
//  while a few absolute origins are best-effort. The subview tree, images, text bindings, colours,
//  fonts, corner radius and border styling are exact.
//

#import "FriendListDetailChara.h"

#import "neEngineBridge.h"                    // neSceneManager::isPadDisplay
#import "DownloadMain.h"                      // FriendListData
#import "AppDelegate.h"                       // +appAppSupportDirectory
#import "AppFont.h"                           // AppMaruFontName()
#import "Game/Data/Chara/CharaManager.h"      // gCharaManager
#import "Game/Data/Chara/CharaInfo.h"         // charaName / skillName / skillId
#import "Game/Data/Chara/SkillData.h"         // GetSkillDataStruct / SkillDataStruct

@implementation FriendListDetailChara {
    NSValue *_friendData;      // the tapped friend's FriendListData (retained), @0x38
    BOOL _isAnimationing;      // open/close guard, @0x3c
}

// @ 0xbac58
- (instancetype)initWithFrame:(CGRect)frame friendData:(NSValue *)friendData {
    // NB: the binary calls -[UIImageView initWithFrame:] with a zero rect (the popup is then sized
    // by its window image + re-centred), ignoring the passed frame.
    self = [super initWithFrame:CGRectZero];
    _friendData = friendData;   // stored before the nil-check, matching the binary
    if (self == nil) {
        return self;
    }

    FriendListData data;
    [friendData getValue:&data];
    const short charaId = data.charaId;

    const BOOL isPad = neSceneManager::isPadDisplay();
    const CGFloat s = isPad ? 2.0f : 1.0f;   // DAT_000bbb04 (phone) / DAT_000bbb08 (iPad)

    // Window backdrop (self is the image view).
    [self setImage:[UIImage imageNamed:@"frilis_window_chara"]];
    [self setUserInteractionEnabled:YES];

    // Close button, top-right; dismisses the popup.
    UIButton *closeButton = [[UIButton alloc] init];
    UIImage *closeImg = [UIImage imageNamed:@"frilis_btn_close"];
    [closeButton setFrame:CGRectMake(237.0f * s, 8.0f * s, closeImg.size.width, closeImg.size.height)];
    [closeButton setImage:closeImg forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(startCloseAnimation)
          forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:closeButton];

    // Friend's chara portrait (downloaded 2x art from Application Support).
    NSString *portraitFile = [NSString stringWithFormat:@"result_chara_%03d_2x.png", (int)charaId];
    NSURL *portraitURL = [NSURL fileURLWithPath:
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:portraitFile]];
    UIImageView *portrait = [[UIImageView alloc]
        initWithImage:[UIImage imageWithData:[NSData dataWithContentsOfURL:portraitURL]]];
    // Frame scaled from the portrait's own size (constants 29.5, 0.2); NEON-spilled origin.
    CGRect pf = portrait.frame;
    [portrait setFrame:CGRectMake(29.5f * s, 0.2f * s * pf.size.height,
                                  pf.size.width * s, pf.size.height * s)];
    [self addSubview:portrait];

    // Rounded, bordered skill card.
    UIView *card = [[UIView alloc] init];
    [card setFrame:CGRectMake(137.0f * s, 0, 323.0f * s, 122.0f * s)];
    card.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"back_bg_st"]];
    card.center = CGPointMake(self.bounds.size.width * 0.5f, card.center.y);
    card.layer.cornerRadius = 5.0f * s;
    // Border rgb(255,176,176) = (1.0, 0.6902, 0.6902).
    card.layer.borderColor = [UIColor colorWithRed:1.0f green:0.69042969f
                                              blue:0.69042969f alpha:1.0f].CGColor;
    card.layer.borderWidth = 2.5f * s;
    [self addSubview:card];

    // Chara icon inside the card (built-in charas from the bundle, downloaded ones from disk).
    NSString *iconFile = [NSString stringWithFormat:@"sgc_icon_%03d.png", (int)charaId];
    UIImage *iconImg;
    if (charaId > 0x1d) {
        iconImg = [UIImage imageWithContentsOfFile:
            [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:iconFile]];
    } else {
        iconImg = [UIImage imageNamed:iconFile];
    }
    UIImageView *iconView = [[UIImageView alloc]
        initWithFrame:CGRectMake(0, 0, 44.0f * s, 44.0f * s)];   // DAT_000bb0bc = 44
    [iconView setImage:iconImg];
    iconView.backgroundColor = [UIColor whiteColor];
    iconView.clipsToBounds = YES;
    iconView.center = CGPointMake(card.frame.size.width * 0.5f, iconView.center.y);
    iconView.layer.cornerRadius = 5.0f * s;
    iconView.layer.borderColor = [UIColor colorWithRed:1.0f green:0.69042969f
                                                  blue:0.69042969f alpha:1.0f].CGColor;
    iconView.layer.borderWidth = 2.5f * s;
    [card addSubview:iconView];

    // Resolve the character record + its skill (lazy gCharaManager guard in the binary is a C++
    // local-static init; here the global is already loaded by the time a friend can be tapped).
    CharaInfo *info = gCharaManager.availableInfoForCharaId(charaId);
    const SkillDataStruct *skill = GetSkillDataStruct((int)info.skillId);

    // Chara name label.
    UILabel *nameLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(107.0f * s, 62.0f * s, 20.0f * s, 20.0f * s)];
    nameLabel.backgroundColor = [UIColor whiteColor];
    nameLabel.textColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1.0f];
    nameLabel.text = info.charaName;
    nameLabel.font = [UIFont fontWithName:AppMaruFontName() size:9.0f * s];
    nameLabel.adjustsFontSizeToFitWidth = YES;
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.layer.cornerRadius = 5.0f * s;
    nameLabel.center = CGPointMake(card.frame.size.width * 0.5f, nameLabel.center.y);
    [card addSubview:nameLabel];

    // Speech bubble holding the skill name.
    UIImageView *fukidasi = [[UIImageView alloc]
        initWithImage:[UIImage imageNamed:@"frilis_fukidasi"]];
    // Positioned below the name label, offset by 7pt*scale (constant 0x40e00000) + half its height.
    CGFloat fukidasiCX = card.frame.size.width * 0.5f;
    CGFloat fukidasiCY = nameLabel.frame.origin.y + nameLabel.frame.size.height
                       + 7.0f * s + fukidasi.image.size.height * 0.5f;
    fukidasi.center = CGPointMake(fukidasiCX, fukidasiCY);
    [card addSubview:fukidasi];

    // Skill name label (centred in the bubble).
    UILabel *skillNameLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(0, 0, 96.0f * s, 19.0f * s)];   // DAT_000bba1c = 96
    skillNameLabel.backgroundColor = [UIColor clearColor];
    skillNameLabel.textColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1.0f];
    skillNameLabel.text = info.skillName;
    skillNameLabel.font = [UIFont fontWithName:AppMaruFontName() size:7.5f * s];
    skillNameLabel.adjustsFontSizeToFitWidth = YES;
    skillNameLabel.textAlignment = NSTextAlignmentCenter;
    skillNameLabel.center = CGPointMake(fukidasi.frame.size.width * 0.5f, skillNameLabel.center.y);
    [fukidasi addSubview:skillNameLabel];

    // Skill description (multi-line, centred in the bubble).
    UILabel *skillDescLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(52.0f * s, 110.0f * s, 22.0f * s, 14.0f * s)];
    skillDescLabel.backgroundColor = [UIColor clearColor];
    skillDescLabel.textColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1.0f];
    skillDescLabel.text = skill->description;
    skillDescLabel.font = [UIFont fontWithName:AppMaruFontName() size:5.0f * s];
    skillDescLabel.textAlignment = NSTextAlignmentCenter;
    skillDescLabel.numberOfLines = 0;
    skillDescLabel.center = CGPointMake(fukidasi.frame.size.width * 0.5f, skillDescLabel.center.y);
    [fukidasi addSubview:skillDescLabel];

    // Sugoroku chara art, centred in the card.
    NSString *sugoFile = [NSString stringWithFormat:@"sugo_chara_%03d.png", (int)charaId];
    NSURL *sugoURL = [NSURL fileURLWithPath:
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:sugoFile]];
    UIImageView *sugoView = [[UIImageView alloc]
        initWithImage:[UIImage imageWithData:[NSData dataWithContentsOfURL:sugoURL]]];
    sugoView.backgroundColor = [UIColor clearColor];
    CGRect sf = sugoView.frame;
    // Scaled by 0.22 (DAT_000bbb14) then the global scale; NEON-spilled origin.
    [sugoView setFrame:CGRectMake(0, 0, sf.size.width * 0.22f * s, sf.size.height * 0.22f * s)];
    sugoView.center = CGPointMake(card.frame.size.width * 0.5f, sugoView.center.y);
    [card addSubview:sugoView];

    return self;
}

// dealloc @ 0xbbb18 — ARC-omitted (super-only override; no ivar releases).

// @ 0xbbb48 — fade in over 0.3s (DAT_000bbc10).
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    [self setAlpha:0];
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    [self setAlpha:1.0f];
    [UIView commitAnimations];
}

// @ 0xbbc18
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0xbbc30 — decide SE, then fade out over 0.3s (DAT_000bbcf8). Note the binary clears the guard
// here (rather than setting it), matching the source.
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = NO;
    neEngine::playSystemSe(2);
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    [self setAlpha:0];
    [UIView commitAnimations];
}

// @ 0xbbd00
- (void)endCloseAnimation {
    [self removeFromSuperview];
    _isAnimationing = NO;
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
