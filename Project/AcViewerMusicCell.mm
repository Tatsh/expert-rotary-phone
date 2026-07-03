//
//  AcViewerMusicCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "AcViewerMusicCell.h"

#import "AcMusicData.h"
#import "AppFont.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"

// One difficulty level label (identical layout for all four tiers; only the colour and the
// level number differ). The binary unrolls this inline four times; collapsed here.
static UILabel *AcvMakeLevelLabel(UIColor *color, int level) {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.backgroundColor = [UIColor clearColor];
    lbl.textColor = color;
    lbl.highlightedTextColor = [UIColor whiteColor];
    lbl.font = [UIFont fontWithName:AppFontName() size:14.0f];
    lbl.textAlignment = NSTextAlignmentCenter;
    lbl.adjustsFontSizeToFitWidth = YES;
    lbl.minimumScaleFactor = 0.5f;
    lbl.frame = CGRectMake(3.0f, 9.0f, 40.0f, 26.0f);
    lbl.text = [NSString stringWithFormat:@"%d", level];
    return lbl;
}

@implementation AcViewerMusicCell {
    BOOL _isPad;
    int _offsetForPad1;   // extra x offset on iPad (50)
    int _offsetForPad2;
    UIImageView *_bgImgView;  // banner background (not retained; lives in the view tree)
    UILabel *_titleLbl;       // song / genre title (idem)
    UILabel *_lvEsLbl;        // easy level number, hosted in easyBtn (idem)
    UILabel *_lvNLbl;         // normal level number, hosted in normalBtn (idem)
    UILabel *_lvHLbl;         // hyper level number, hosted in hyperBtn (idem)
    UILabel *_lvExLbl;        // ex level number, hosted in exBtn (idem)
}

// @ 0x40430 — build the four difficulty buttons in a row at y = 51. The first button
// starts at x = 22 (pre-iOS 7) or 32, plus 50 more on iPad; each subsequent button
// sits just right of the previous. Tags 100..103 identify the chosen difficulty.
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    _isPad = neSceneManager::isPadDisplay();
    _offsetForPad1 = 0;
    _offsetForPad2 = 0;
    if (_isPad) {
        _offsetForPad1 = 50;
        _offsetForPad2 = 0;
    }

    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        CGFloat firstX = (UIDevice.currentDevice.systemVersion.floatValue < 7.0f ? 22 : 32)
                       + _offsetForPad2;

        NSArray *images = @[ @"acv_viewer_diff_ea", @"acv_viewer_diff_n",
                             @"acv_viewer_diff_h", @"acv_viewer_diff_ex" ];
        UIButton *prev = nil;
        for (NSUInteger i = 0; i < 4; i++) {
            UIButton *btn = [[UIButton alloc] init];
            UIImage *img = [UIImage imageNamed:images[i]];
            CGFloat x = (prev == nil) ? firstX : CGRectGetMaxX(prev.frame);
            [btn setBackgroundImage:img forState:UIControlStateNormal];
            btn.frame = CGRectMake(x, 51, img.size.width, img.size.height);
            btn.tag = 100 + (NSInteger)i;
            switch (i) {
                case 0: self.easyBtn = btn; break;
                case 1: self.normalBtn = btn; break;
                case 2: self.hyperBtn = btn; break;
                case 3: self.exBtn = btn; break;
            }
            prev = btn;
        }
    }
    return self;
}

// dealloc @ 0x40954 — ARC-omitted (object ivars only: releases the four difficulty buttons).

// @ 0x409e0 — bind one arcade song row: a banner background (on iPad centred and vertically
// offset by half its height), the song or genre title, and the level number for each available
// difficulty drawn inside its matching difficulty button. A difficulty whose level is < 1 has
// no chart, so its button is pulled from the view.
- (void)setData:(AcMusicData *)data {
    [_bgImgView removeFromSuperview];
    [_titleLbl removeFromSuperview];
    [_lvEsLbl removeFromSuperview];
    [_lvNLbl removeFromSuperview];
    [_lvHLbl removeFromSuperview];
    [_lvExLbl removeFromSuperview];
    _bgImgView = nil;
    _titleLbl = nil;
    _lvEsLbl = nil;
    _lvNLbl = nil;
    _lvHLbl = nil;
    _lvExLbl = nil;

    float osVersion = UIDevice.currentDevice.systemVersion.floatValue;

    // Banner background: created at cell bounds, then resized to the banner image.
    _bgImgView = [[UIImageView alloc] initWithFrame:self.bounds];
    UIImage *banner = [UIImage imageNamed:@"acv_viewer_banner"];
    [_bgImgView setImage:banner];
    [_bgImgView setFrame:CGRectMake(0.0f, 0.0f, banner.size.width, banner.size.height)];
    if (!_isPad) {
        self.backgroundView = _bgImgView;
    } else {
        // iPad: centre the banner horizontally and drop it so its top sits at y = 0.
        CGFloat centerX = (osVersion < 7.0f) ? 150.0f : 160.0f;
        [_bgImgView setCenter:CGPointMake(centerX, banner.size.height * 0.5f)];
        [self.contentView addSubview:_bgImgView];
    }
    self.backgroundColor = [UIColor clearColor];

    // Title label (song name, or genre name when the arcade viewer is in genre mode).
    _titleLbl = [[UILabel alloc] init];
    _titleLbl.backgroundColor = [UIColor clearColor];
    _titleLbl.textColor = [UIColor colorWithRed:48.0f / 255.0f green:48.0f / 255.0f blue:48.0f / 255.0f alpha:1.0f];
    _titleLbl.highlightedTextColor = [UIColor whiteColor];
    _titleLbl.font = [UIFont fontWithName:AppFontName() size:16.0f];
    _titleLbl.textAlignment = NSTextAlignmentCenter;
    _titleLbl.adjustsFontSizeToFitWidth = YES;
    _titleLbl.minimumScaleFactor = 0.8f;
    _titleLbl.frame = CGRectMake(_offsetForPad2 + 20, 15.0f, osVersion < 7.0f ? 263.0f : 280.0f, 18.0f);
    _titleLbl.backgroundColor = [UIColor clearColor];
    _titleLbl.text = [UserSettingData isAcvGenreName] ? [data genreName] : [data musicName];
    [self.contentView addSubview:_titleLbl];

    // Difficulty level numbers, each hosted inside its difficulty button.
    if ([data lvEasy] < 1) {
        [self.easyBtn removeFromSuperview];
    } else {
        _lvEsLbl = AcvMakeLevelLabel(
            [UIColor colorWithRed:113.0f / 255.0f green:179.0f / 255.0f blue:255.0f / 255.0f alpha:1.0f],
            [data lvEasy]);
        [self.easyBtn addSubview:_lvEsLbl];
        [self.contentView addSubview:self.easyBtn];
    }

    if ([data lvNormal] < 1) {
        [self.normalBtn removeFromSuperview];
    } else {
        _lvNLbl = AcvMakeLevelLabel(
            [UIColor colorWithRed:59.0f / 255.0f green:117.0f / 255.0f blue:28.0f / 255.0f alpha:1.0f],
            [data lvNormal]);
        [self.normalBtn addSubview:_lvNLbl];
        [self.contentView addSubview:self.normalBtn];
    }

    if ([data lvHyper] < 1) {
        [self.hyperBtn removeFromSuperview];
    } else {
        _lvHLbl = AcvMakeLevelLabel(
            [UIColor colorWithRed:207.0f / 255.0f green:123.0f / 255.0f blue:15.0f / 255.0f alpha:1.0f],
            [data lvHyper]);
        [self.hyperBtn addSubview:_lvHLbl];
        [self.contentView addSubview:self.hyperBtn];
    }

    if ([data lvEx] < 1) {
        [self.exBtn removeFromSuperview];
    } else {
        _lvExLbl = AcvMakeLevelLabel(
            [UIColor colorWithRed:255.0f / 255.0f green:133.0f / 255.0f blue:188.0f / 255.0f alpha:1.0f],
            [data lvEx]);
        [self.exBtn addSubview:_lvExLbl];
        [self.contentView addSubview:self.exBtn];
    }
}

@end
