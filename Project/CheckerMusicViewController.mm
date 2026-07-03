//
//  CheckerMusicViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  .mm because init/back/select reach the C++ engine bridge
//  (neSceneManager::isPadDisplay(), neEngine::playSystemSe()).
//

#import "CheckerMusicViewController.h"

#import "CheckerMusicCell.h"    // in-project row cell (setData:)
#import "CheckerDetail.h"       // pushed on row select
#import "DownloadMain.h"        // dealloc clears itself as the get-visitor delegate
#import "neEngineBridge.h"

// Category list-header banner images, indexed by category (0..23); >=24 uses "near".
static NSString *const kMlistHeader[24] = {
    @"ppc_mlist_header_etc", @"ppc_mlist_header_tv",
    @"ppc_mlist_header_p01", @"ppc_mlist_header_p02", @"ppc_mlist_header_p03", @"ppc_mlist_header_p04",
    @"ppc_mlist_header_p05", @"ppc_mlist_header_p06", @"ppc_mlist_header_p07", @"ppc_mlist_header_p08",
    @"ppc_mlist_header_p09", @"ppc_mlist_header_p10", @"ppc_mlist_header_p11", @"ppc_mlist_header_p12",
    @"ppc_mlist_header_p13", @"ppc_mlist_header_p14", @"ppc_mlist_header_p15", @"ppc_mlist_header_p16",
    @"ppc_mlist_header_p17", @"ppc_mlist_header_p18", @"ppc_mlist_header_p19", @"ppc_mlist_header_p20",
    @"ppc_mlist_header_p21", @"ppc_mlist_header_p22"
};

@interface CheckerMusicViewController ()
- (void)touchedBackButton:(id)sender;
@end

@implementation CheckerMusicViewController {
    NSArray *_scoreDataArray;    // the category's ArcadeScoreData rows
}

// @ 0xd27b8
- (instancetype)initWithScoreData:(NSArray *)scoreDataArray category:(short)category {
    self = [super initWithStyle:UITableViewStyleGrouped];
    _scoreDataArray = scoreDataArray;
    if (!self) {
        return nil;
    }

    BOOL isPad = neSceneManager::isPadDisplay();
    self.tableView.rowHeight = isPad ? 79.0f : 59.0f;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [UIColor clearColor];
    self.tableView.backgroundView = nil;
    if (!isPad) {
        // Phone: pale mint list background.
        self.tableView.backgroundColor = [UIColor colorWithRed:0.615686f green:1.0f
                                                          blue:0.913725f alpha:1.0f];
    } else {
        self.tableView.backgroundColor = [UIColor clearColor];
    }

    // Category list-header banner, hosted in a container tall enough to pad it below.
    NSString *headerName = (category < 24) ? kMlistHeader[category] : @"ppc_mlist_header_near";
    UIImage *headerImg = [UIImage imageNamed:headerName];
    UIImageView *headerImgView = [[UIImageView alloc] initWithImage:headerImg];
    [headerImgView setFrame:CGRectMake(0.0f, 17.0f, headerImg.size.width, headerImg.size.height)];

    UIView *headerView = [[UIView alloc] init];
    CGFloat headerViewHeight = headerImg.size.height + headerImgView.frame.origin.y;
    if (isPad) {
        headerViewHeight += 20.0f;
    } else if (UIDevice.currentDevice.systemVersion.floatValue >= 7.0f) {
        headerViewHeight += 10.0f;
    }
    headerView.frame = CGRectMake(0.0f, 0.0f, headerImg.size.width, headerViewHeight);
    [headerView addSubview:headerImgView];
    self.tableView.tableHeaderView = headerView;

    // Phone: a full-screen paper background behind the list.
    if (!isPad) {
        UIImage *bg = [UIImage imageNamed:@"friman_bg"];
        UIImageView *bgView = [[UIImageView alloc] initWithImage:bg];
        [bgView setFrame:CGRectMake(0.0f, 0.0f, bg.size.width, bg.size.height)];
        self.tableView.backgroundView = bgView;
    }

    // Custom back button in the left nav slot.
    NSString *backName = isPad ? @"pl_checker_return" : @"navi_btn_back";
    UIImage *backImg = [UIImage imageNamed:backName];
    UIButton *backButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f,
                                                                      backImg.size.width,
                                                                      backImg.size.height)];
    [backButton setBackgroundImage:backImg forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(touchedBackButton:)
         forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    if (neSceneManager::isPadDisplay()) {
        self.navigationItem.hidesBackButton = YES;
    }
    return self;
}

// @ 0xd2e20 — clear the shared DownloadMain's get-visitor delegate if it points here.
- (void)dealloc {
    DownloadMain *dm = [DownloadMain getInstance];
    if ([dm delegateGetVisitor] == self) {
        [dm setDelegateGetVisitor:nil];
    }
    // ARC synthesizes [super dealloc].
}

// viewDidLoad @ 0xd2e98 — super-only override, ARC/omit (no added behavior).
// didReceiveMemoryWarning @ 0xd2ec4 — super-only override, ARC/omit (no added behavior).

// @ 0xd2ef0
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xd2ef4
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_scoreDataArray != nil) {
        return (NSInteger)_scoreDataArray.count;
    }
    return 0;
}

// @ 0xd2f1c
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"Cell%ld_%ld",
                            (long)indexPath.section, (long)indexPath.row];
    CheckerMusicCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[CheckerMusicCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:identifier];
    }
    [cell setData:_scoreDataArray[indexPath.row]];
    return cell;
}

// @ 0xd3028
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0xd3030 — push the per-song CheckerDetail; on iPad first grow the split nav pane.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.navigationController.topViewController == self && indexPath.section == 0) {
        neEngine::playSystemSe(1);   // decide SE
        CheckerDetail *detail =
            [[CheckerDetail alloc] initWithScoreData:_scoreDataArray[indexPath.row]];
        BOOL notPad = !neSceneManager::isPadDisplay();
        if (!notPad) {
            [UIView animateWithDuration:0.6f delay:0.0f
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                                 self.navigationController.view.frame =
                                     CGRectMake(385.0f, 250.0f, 320.0f, 530.0f);
                             }
                             completion:nil];
        }
        [self.navigationController pushViewController:detail animated:notPad];
    }
}

// @ 0xd3254
- (void)touchedBackButton:(id)sender {
    if (self.navigationController.topViewController != self) {
        return;
    }
    neEngine::playSystemSe(2);   // cancel SE
    [self.navigationController popViewControllerAnimated:YES];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
