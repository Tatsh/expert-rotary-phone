//
//  SettingTableViewController.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "SettingTableViewController.h"

#import "SettingCustomerTableViewController.h"
#import "SettingGameTableViewController.h"
#import "SettingHowtoTableViewController.h"
#import "SettingOtherTableViewController.h"
#import "neEngineBridge.h"

static UIViewController *RootVC() {
    return (__bridge UIViewController *)neSceneManager::rootViewController();
}

@implementation SettingTableViewController {
    BOOL _isAnimationing;
}

// @ 0x7eaf8 — 61 px rows; a patterned "back_bg_st" background on phone; on iPad a
// clear background with a "side_bar_bg" backgroundView and (pre-iOS 7) a top inset.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    if ((self = [super initWithStyle:style])) {
        self.tableView.rowHeight = 61.0f;
        if (neSceneManager::isPadDisplay()) {
            self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
            self.tableView.separatorColor = [UIColor clearColor];
            if (UIDevice.currentDevice.systemVersion.floatValue < 7.0f) {
                self.tableView.contentInset = UIEdgeInsetsMake(20, 0, 0, 0);
            }
            self.view.backgroundColor = [UIColor clearColor];
            self.tableView.backgroundView = [[[UIImageView alloc]
                initWithImage:[UIImage imageNamed:@"side_bar_bg"]] autorelease];
        } else {
            self.tableView.backgroundColor =
                [UIColor colorWithPatternImage:[UIImage imageNamed:@"back_bg_st"]];
        }
    }
    return self;
}

// Wrap self in a navigation controller (the phone presentation).
- (UINavigationController *)initAtNavigationController {
    [self initWithStyle:UITableViewStyleGrouped];
    return [[UINavigationController alloc] initWithRootViewController:self];
}

#pragma mark - Table (the setting categories)

// The top settings list opens the four sub-setting screens (row set derived from the
// Setting*TableViewController classes; the exact per-row labels/icons live in the
// binary's cell-config at 0x7e3c4).
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 4;   // game / how-to / customer / other
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const kId = @"SettingCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kId];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:kId] autorelease];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UIViewController *sub = nil;
    switch (indexPath.row) {
        case 0: sub = [[[SettingGameTableViewController alloc]
                    initWithStyle:UITableViewStyleGrouped] autorelease]; break;
        case 1: sub = [[[SettingHowtoTableViewController alloc]
                    initWithStyle:UITableViewStyleGrouped] autorelease]; break;
        case 2: sub = [[[SettingCustomerTableViewController alloc]
                    initWithStyle:UITableViewStyleGrouped] autorelease]; break;
        case 3: sub = [[[SettingOtherTableViewController alloc]
                    initWithStyle:UITableViewStyleGrouped] autorelease]; break;
    }
    if (sub != nil) {
        [self.navigationController pushViewController:sub animated:YES];
    }
}

#pragma mark - Modal open/close animation (shared lifecycle)

// @ 0x7efec
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.view.alpha = 1;
    self.navigationController.view.alpha = 1;
    [UIView commitAnimations];
}

// @ 0x7f118
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0x7f130 — fade out, then notify the host.
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView commitAnimations];
}

// @ 0x7f248 — remove and hand control back to MainViewController.
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [RootVC() performSelector:@selector(SettingEndCallBack)];
    _isAnimationing = NO;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
