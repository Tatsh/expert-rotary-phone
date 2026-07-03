//
//  LoginBonusView.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  ARC. (.mm: uses the C++ neEngine bridge for the root scene view / system SE.)
//

#import "LoginBonusView.h"
#import "DownloadMain.h"          // +getInstance, .loginCnt, .loginBonusId, .isLoginCntUpdate
#import "UserSettingData.h"       // +getLoginBonusCnt/+saveLoginBonusCnt:, +treasurePoint/+saveTreasurePoint:, +saveOpenedLoginBonusId:, +playerId
#import "MusicManager.h"          // +getInstance, -openLoginBonusMusic
#import "neEngineBridge.h"        // neSceneManager::rootViewController(), neEngine::playSystemSe(int)

#import <stdlib.h>

// ---------------------------------------------------------------------------
// Login-bonus reward definition table.
//
// getReward / +getRewardMaxCnt / showAlertView all walk the same const table.
// Ghidra: base &DAT_001320d4 is &entry[0].type; the record actually starts one
// int earlier (the required-login-count field). Records are 12 bytes and the
// table is indexed by DownloadMain.loginBonusId with a 0x600-byte (128-record)
// stride. A record with type == kLoginBonusRewardEnd terminates a row.
//
// Record layout recovered from the blob at 0x001320d0:
//   +0x0 int requiredLoginCnt   +0x4 int type   +0x8 NSString *value
// The value cell is a pointer to a baked constant NSString whose -intValue yields the
// treasure-point amount (type 0). loginBonusId 0's row is days 1..N of treasure points
// cycling through "300"/"100"/"800" (@ 0x00138458 / 0x00138468 / 0x00138478).
//
// TODO(dep): the blob itself stays opaque — it is a large 2-D table indexed by the
// server-driven DownloadMain.loginBonusId, and each row's `value` cells are pointers to
// Objective-C NSString objects baked at absolute addresses, not a plain C array.
// -rewardTableForLoginBonusId: reproduces exactly the address arithmetic the binary
// performs so the reward logic below stays faithful; supply the extracted blob (with its
// NSString objects mapped) to make it runnable.
// ---------------------------------------------------------------------------
typedef struct {
    int requiredLoginCnt;                  // login count at which this reward unlocks
    int type;                              // 0 = treasure point, 1 = music unlock, 2 = terminator
    NSString * __unsafe_unretained value;  // type 0: treasure amount as text (read via -intValue)
} LoginBonusRewardEntry;

enum {
    kLoginBonusRewardTreasure = 0,
    kLoginBonusRewardMusic    = 1,
    kLoginBonusRewardEnd      = 2,
};

@interface LoginBonusView () {
    UIImageView *m_BgImgView;   // the "login_board" background (stamps are its subviews)
    int          m_OldLoginCnt; // login count already acknowledged on this board
    BOOL         m_IsTouch;     // guard so the "stamp today" tap only fires once
}
- (void)touchEvent:(id)sender;   // @ 0x7c8e0
- (void)showAlertView;           // @ 0x7cc68
+ (const LoginBonusRewardEntry *)rewardTableForLoginBonusId:(int)loginBonusId;  // @ 0x7c05c (opaque blob; see note)
@end

@implementation LoginBonusView

// @ 0x7c05c — helper mirroring the binary's table base arithmetic (see note above).
+ (const LoginBonusRewardEntry *)rewardTableForLoginBonusId:(int)loginBonusId {
    // Const blob baked at 0x001320d0 (Ghidra &DAT_001320d4 - offsetof(type)); see note above.
    const uint8_t *base = (const uint8_t *)0x001320d0;
    return (const LoginBonusRewardEntry *)(base + (size_t)loginBonusId * 0x600);
}

// @ 0x7bf70 — count reward rows until the terminator (type == 2), capped at 128.
+ (int)getRewardMaxCnt {
    int loginBonusId = [DownloadMain getInstance].loginBonusId;
    const LoginBonusRewardEntry *table = [self rewardTableForLoginBonusId:loginBonusId];
    int cnt = 0;
    do {
        if (table[cnt].type == kLoginBonusRewardEnd) {
            return cnt;
        }
        cnt++;
    } while (cnt < 0x80);
    return cnt;
}

// @ 0x7bfc8 — nib path funnels into -init.
- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self init];
}

// @ 0x7bfd8 — frame path funnels into -init.
- (instancetype)initWithFrame:(CGRect)frame {
    return [self init];
}

// @ 0x7bfe8 — designated setup: size to the root scene view, build the board.
- (instancetype)init {
    UIView *rootView = neSceneManager::rootViewController().view;
    CGRect frame = rootView ? rootView.frame : CGRectZero;

    self = [super initWithFrame:frame];
    if (self) {
        DownloadMain *dl = [DownloadMain getInstance];

        // How many login days the board has already acknowledged. First ever
        // show (0) starts one day behind the current login count.
        m_OldLoginCnt = [UserSettingData getLoginBonusCnt];
        if (m_OldLoginCnt == 0) {
            m_OldLoginCnt = dl.loginCnt - 1;
        }
        m_IsTouch = NO;

        // Board background, centred in self.
        UIImage *boardImg = [UIImage imageNamed:@"login_board"];
        m_BgImgView = [[UIImageView alloc] initWithImage:boardImg];
        m_BgImgView.frame = CGRectMake(0.0f, 0.0f, boardImg.size.width, boardImg.size.height);
        m_BgImgView.center = CGPointMake(self.frame.size.width * 0.5f,
                                         self.frame.size.height * 0.5f);
        m_BgImgView.userInteractionEnabled = YES;
        [self addSubview:m_BgImgView];

        // Deterministic per-player stamp art (RNG seeded by player id).
        srand([[UserSettingData playerId] intValue]);

        // One "login_popn" stamp per already-consumed login day, laid out in a
        // 5-column grid on the board. Ghidra base offsets: x = 43 + col*(w+3),
        // y = 113 + row*h  (the terminator/limit is loginCnt-1 stamps).
        int maxCnt = [LoginBonusView getRewardMaxCnt];
        for (int i = 0; i < maxCnt; i++) {
            if (dl.loginCnt - 1 <= i) {
                break;
            }
            NSString *name = [NSString stringWithFormat:@"login_popn%02d", (int)(random() % 5 + 1)];
            UIImage *stampImg = [UIImage imageNamed:name];
            UIImageView *stamp = [[UIImageView alloc] initWithImage:stampImg];

            int col = i % 5;
            int row = i / 5;
            CGFloat x = (CGFloat)((stampImg.size.width + 3) * col + 0x2b);   // 43
            CGFloat y = (CGFloat)(stampImg.size.height * row + 0x71);        // 113
            stamp.frame = CGRectMake(x, y, stampImg.size.width, stampImg.size.height);
            [m_BgImgView addSubview:stamp];
        }

        // Full-board transparent button that forwards taps to -touchEvent:.
        UIButton *btn = [[UIButton alloc] initWithFrame:self.frame];
        btn.userInteractionEnabled = YES;
        btn.backgroundColor = [UIColor clearColor];
        [btn addTarget:self action:@selector(touchEvent:)
              forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];

        self.hidden = YES;
        [rootView addSubview:self];
        [rootView bringSubviewToFront:self];
    }
    return self;
}

// @ 0x7c540 — drop the board background, then up-chain.
- (void)dealloc {
    if (m_BgImgView != nil) {
        [m_BgImgView removeFromSuperview];
        m_BgImgView = nil;
    }
    // (ARC synthesises [super dealloc]; kept explicit in Ghidra @ 0x7c540.)
}

// @ 0x7c594 — grant every reward whose unlock threshold was crossed since the
// board was last acknowledged (m_OldLoginCnt < threshold <= current loginCnt).
- (void)getReward {
    DownloadMain *dl = [DownloadMain getInstance];
    int loginBonusId = dl.loginBonusId;
    const LoginBonusRewardEntry *table = [LoginBonusView rewardTableForLoginBonusId:loginBonusId];

    int maxCnt = [LoginBonusView getRewardMaxCnt];
    for (int i = 0; i < maxCnt; i++) {
        int threshold = table[i].requiredLoginCnt;
        if (m_OldLoginCnt < threshold && threshold <= dl.loginCnt) {
            if (table[i].type == kLoginBonusRewardTreasure) {
                short have = [UserSettingData treasurePoint];
                // Ghidra reads the amount via -[value intValue] (value is a baked NSString).
                [UserSettingData saveTreasurePoint:(short)(have + [table[i].value intValue])];
            } else if (table[i].type == kLoginBonusRewardMusic) {
                [UserSettingData saveOpenedLoginBonusId:dl.loginBonusId];
                [[MusicManager getInstance] openLoginBonusMusic];
            }
        }
    }
}

// @ 0x7c728 — grant rewards, remember today's count, reveal with a shrink-in pop.
- (void)show {
    [self getReward];

    DownloadMain *dl = [DownloadMain getInstance];
    [UserSettingData saveLoginBonusCnt:dl.loginCnt];

    self.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
    self.hidden = NO;
    [UIView animateWithDuration:0.3
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
    }
                     completion:^(BOOL finished) {
        // @ 0x7c870 resetViewTransform — belt-and-suspenders identity restore
        // (setTransform: with the identity matrix; 0x3f800000 on the diagonal).
        self.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
    }];
}

// @ 0x7c8e0 — first board tap: stamp today's login_popn icon with a pop-in, once.
- (void)touchEvent:(id)sender {
    DownloadMain *dl = [DownloadMain getInstance];
    if (m_IsTouch) {
        return;
    }

    neEngine::playSystemSe(1);

    NSString *name = [NSString stringWithFormat:@"login_popn%02d", (int)(random() % 5 + 1)];
    UIImage *stampImg = [UIImage imageNamed:name];
    UIImageView *stamp = [[UIImageView alloc] initWithImage:stampImg];

    // Next free grid cell = (loginCnt - 1).
    int slot = dl.loginCnt - 1;
    int col = slot % 5;
    int row = slot / 5;
    CGFloat x = (CGFloat)((stampImg.size.width + 3) * col + 0x2b);   // 43
    CGFloat y = (CGFloat)(stampImg.size.height * row + 0x71);        // 113
    stamp.frame = CGRectMake(x, y, stampImg.size.width, stampImg.size.height);

    [m_BgImgView addSubview:stamp];
    stamp.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
    self.hidden = NO;
    [UIView animateWithDuration:0.2
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        stamp.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
    }
                     completion:^(BOOL finished) {
        // @ 0x7cbd8 resetViewTransformDup — identity restore on the stamp (duplicate of
        // resetViewTransform; setTransform: with the identity matrix).
        stamp.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
    }];

    m_IsTouch = YES;
}

// @ 0x7cc68 — advance to the next acknowledged day and describe its reward in a
// gift-styled CustomAlertView (self is its delegate).
- (void)showAlertView {
    DownloadMain *dl = [DownloadMain getInstance];
    int loginBonusId = dl.loginBonusId;
    dl.isLoginCntUpdate = NO;
    m_OldLoginCnt += 1;

    // UTF-16 CFString recovered @ 0x00138428 -> data 0x0012c662 : "ログイン%d日目"
    // (the %d is the day being acknowledged, m_OldLoginCnt after the increment above).
    NSString *title = [NSString stringWithFormat:@"ログイン%d日目", m_OldLoginCnt];

    // Reward message CFStrings recovered from the binary:
    //   treasure @ 0x00138448 -> 0x0012c688 : "トレジャーポイントをGET！\n[%@P]"  (value NSString)
    //   music    @ 0x00138438 -> 0x0012c674 : "楽曲を解禁したよ♫"
    //   default  @ 0x00134818                : "" (empty)
    NSString *message = @"";   // cf___ default (empty)
    int maxCnt = [LoginBonusView getRewardMaxCnt];
    const LoginBonusRewardEntry *table = [LoginBonusView rewardTableForLoginBonusId:loginBonusId];
    for (int i = 0; i < maxCnt; i++) {
        if (table[i].requiredLoginCnt == m_OldLoginCnt) {
            if (table[i].type == kLoginBonusRewardTreasure) {
                message = [NSString stringWithFormat:@"トレジャーポイントをGET！\n[%@P]", table[i].value];
            } else if (table[i].type == kLoginBonusRewardMusic) {
                message = @"楽曲を解禁したよ♫";
            }
            break;
        }
    }

    CustomAlertView *alert =
        [[CustomAlertView alloc] initWithView:self
                                         type:CustomAlertViewTypeGift
                                        title:title
                                      message:message
                            cancelButtonTitle:nil
                              otherButtonTitle:@"OK"];
    alert.delegate = self;
    [alert setOpenAnimeType:CustomAlertViewAnimeTypeScale];
    [alert show];
}

// @ 0x7ce50 — CustomAlertViewDelegate. Chain to the next reward day, or close.
- (void)customAlertView:(CustomAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    DownloadMain *dl = [DownloadMain getInstance];
    if (m_OldLoginCnt < dl.loginCnt) {
        [self showAlertView];
    } else {
        // No more days to acknowledge: animate the board away and remove it.
        [UIView animateWithDuration:0.3
                              delay:0.0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            // @ 0x7cf58 zeroViewTransform — collapse to a zero matrix
            // (setTransform: with all six components 0, i.e. scale (0, 0)).
            self.transform = CGAffineTransformMakeScale(0.0f, 0.0f);
        }
                         completion:^(BOOL finished) {
            [self removeFromSuperview];
        }];
    }
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
