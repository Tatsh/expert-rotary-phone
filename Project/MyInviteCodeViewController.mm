//
//  MyInviteCodeViewController.mm
//  pop'n rhythmin
//
//  See MyInviteCodeViewController.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. Objective-C++ for the neEngine::playSystemSe bridge (cancel SE on back).
//

#import "MyInviteCodeViewController.h"

#import "neEngineBridge.h"     // neEngine::playSystemSe (cancel SE)
#import "UserSettingData.h"    // +playerId (the local invite code)

@implementation MyInviteCodeViewController

// @ 0xe8c98 — build the invite-code screen.
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        const CGRect frame = self.view.frame;

        // Full-screen background.
        UIImageView *bg = [[UIImageView alloc] initWithFrame:frame];
        [bg setImage:[UIImage imageNamed:@"friman_bg"]];
        [self.view addSubview:bg];

        // Nav-bar back button.
        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *backBtn = [[UIButton alloc]
            initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self action:@selector(touchedBackButton)
          forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backBtn];

        // "invite" title image (centered horizontally, y=25).
        UIImage *inviteImg = [UIImage imageNamed:@"invite_text_1"];
        UIImageView *inviteView = [[UIImageView alloc] initWithImage:inviteImg];
        inviteView.frame = CGRectMake((frame.size.width - inviteImg.size.width) * 0.5f, 25.0f,
                                      inviteImg.size.width, inviteImg.size.height);
        [self.view addSubview:inviteView];

        // "player" title image (centered horizontally, y=100).
        UIImage *playerImg = [UIImage imageNamed:@"fripre_text_player"];
        UIImageView *playerView = [[UIImageView alloc] initWithImage:playerImg];
        const CGFloat plateX = (frame.size.width - playerImg.size.width) * 0.5f;
        playerView.frame = CGRectMake(plateX, 100.0f, playerImg.size.width, playerImg.size.height);
        [self.view addSubview:playerView];

        // Player id, drawn inside the patterned ID-area plate (same x / width as the "player"
        // image), black text, centered (y=125, height=33).
        UILabel *idLabel = [[UILabel alloc] init];
        idLabel.frame = CGRectMake(plateX, 125.0f, playerImg.size.width, 33.0f);
        idLabel.textAlignment = NSTextAlignmentCenter;
        idLabel.backgroundColor =
            [UIColor colorWithPatternImage:[UIImage imageNamed:@"fripre_idarea_player"]];
        idLabel.textColor = [UIColor blackColor];
        idLabel.text = [UserSettingData playerId];
        [self.view addSubview:idLabel];
    }
    return self;
}

// @ 0xe9194 — nothing beyond the superclass.
- (void)viewDidLoad {
    [super viewDidLoad];
}

// @ 0xe91c0 — nothing beyond the superclass.
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// @ 0xe91ec — back button: play the cancel SE and pop.
- (void)touchedBackButton {
    // Ghidra: NESceneManager_shared(); SysSePlayIntoSlot(&g_pNeSceneManager, 2) — cancel SE.
    neEngine::playSystemSe(2);
    [self.navigationController popViewControllerAnimated:YES];
}

@end
