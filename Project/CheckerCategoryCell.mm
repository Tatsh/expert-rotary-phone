//
//  CheckerCategoryCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "CheckerCategoryCell.h"

#import "neEngineBridge.h"

@implementation CheckerCategoryCell {
    BOOL _isOS7;
    BOOL _isPad;
    int _offsetXForPad;
    int _imgMusicCntX;
    UIImageView *_bgView;             // pad-only: category banner held as a plain subview
    UIImageView *_musicCntBaseView;   // "played" badge background
    UIImageView *_musicCntNumView[3]; // up to 3 played-count digit glyphs
}

// @ 0xcf49c — the music-count label x offset varies by device + OS.
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    _offsetXForPad = 0;
    _isOS7 = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;
    _isPad = neSceneManager::isPadDisplay();
    if (!_isPad) {
        _imgMusicCntX = _isOS7 ? 0xf5 : 0xf0;
    } else if (!_isOS7) {
        _offsetXForPad = 6;
        _imgMusicCntX = 0xec;
    } else {
        _offsetXForPad = 0xe;
        _imgMusicCntX = 0xf4;
    }
    return self;
}

// dealloc @ 0xcf5c8 — ARC-omitted (releases ivars only; synthesized by ARC).

// @ 0xcf5f4 — rebuild the row for a category: a full-bleed banner image whose
// placement depends on device/OS, over a "played" badge showing how many musics
// in this category the player has already played.
- (void)setData:(NSArray *)playedList category:(short)category {
    // Base category banner images, indexed by `category` (0..23); >=24 uses
    // "near".
    static NSString *const kCateBase[24] = {
        @"ppc_cate_base_etc", @"ppc_cate_base_tv",  @"ppc_cate_base_p01", @"ppc_cate_base_p02",
        @"ppc_cate_base_p03", @"ppc_cate_base_p04", @"ppc_cate_base_p05", @"ppc_cate_base_p06",
        @"ppc_cate_base_p07", @"ppc_cate_base_p08", @"ppc_cate_base_p09", @"ppc_cate_base_p10",
        @"ppc_cate_base_p11", @"ppc_cate_base_p12", @"ppc_cate_base_p13", @"ppc_cate_base_p14",
        @"ppc_cate_base_p15", @"ppc_cate_base_p16", @"ppc_cate_base_p17", @"ppc_cate_base_p18",
        @"ppc_cate_base_p19", @"ppc_cate_base_p20", @"ppc_cate_base_p21", @"ppc_cate_base_p22"};
    // Digit glyphs for the played count.
    static NSString *const kPlayNum[10] = {@"ppc_pl_num_0",
                                           @"ppc_pl_num_1",
                                           @"ppc_pl_num_2",
                                           @"ppc_pl_num_3",
                                           @"ppc_pl_num_4",
                                           @"ppc_pl_num_5",
                                           @"ppc_pl_num_6",
                                           @"ppc_pl_num_7",
                                           @"ppc_pl_num_8",
                                           @"ppc_pl_num_9"};

    // Tear down any previously bound subviews (cell reuse).
    if (_musicCntBaseView) {
        [_musicCntBaseView removeFromSuperview];
        _musicCntBaseView = nil;
    }
    for (int i = 0; i < 3; i++) {
        if (_musicCntNumView[i]) {
            [_musicCntNumView[i] removeFromSuperview];
            _musicCntNumView[i] = nil;
        }
    }
    if (_bgView) {
        [_bgView removeFromSuperview];
        _bgView = nil;
    }

    // Category banner.
    UIImageView *baseImg = [[UIImageView alloc] initWithFrame:self.bounds];
    NSString *baseName = (category < 24) ? kCateBase[category] : @"ppc_cate_base_near";
    UIImage *baseImage = [UIImage imageNamed:baseName];
    [baseImg setImage:baseImage];
    [baseImg
        setFrame:CGRectMake(_offsetXForPad, 0.0f, baseImage.size.width, baseImage.size.height)];

    if (!_isPad) {
        float osVersion = UIDevice.currentDevice.systemVersion.floatValue;
        if (osVersion >= 7.0f) {
            // iOS 7+ phone: center the banner in the content view.
            CGRect cf = self.contentView.frame;
            [baseImg setCenter:CGPointMake(cf.size.width * 0.5f, cf.size.height * 0.5f)];
            [self.contentView addSubview:baseImg];
        } else {
            // Pre-iOS 7 phone: install as the cell's background view.
            self.backgroundView = baseImg;
        }
    } else {
        // Pad: keep a reference and add as a plain subview.
        _bgView = baseImg;
        [self.contentView addSubview:baseImg];
    }
    self.backgroundColor = [UIColor clearColor];

    // Played-count badge (only for real categories).
    if (category < 24) {
        UIImage *playedImage = [UIImage imageNamed:@"ppc_cate_played"];
        _musicCntBaseView = [[UIImageView alloc] initWithFrame:CGRectMake(_imgMusicCntX,
                                                                          21.0f,
                                                                          playedImage.size.width,
                                                                          playedImage.size.height)];
        [_musicCntBaseView setImage:playedImage];
        [self.contentView addSubview:_musicCntBaseView];

        int count = static_cast<int>(playedList.count);
        int digitCount = 1;
        for (int t = count; t >= 10; t /= 10) {
            digitCount++;
        }
        int shown = MIN(digitCount, 3);
        // Rightmost (units) digit sits furthest right; earlier digits step left
        // by 10.
        CGFloat x =
            static_cast<CGFloat>(_imgMusicCntX) + 15.0f + static_cast<CGFloat>(shown * 5 - 5);
        int remaining = count;
        for (int i = 0; i < shown; i++) {
            UIImageView *numView =
                [[UIImageView alloc] initWithImage:[UIImage imageNamed:kPlayNum[remaining % 10]]];
            _musicCntNumView[i] = numView;
            [numView setFrame:CGRectMake(x, 26.0f, 12.0f, 15.0f)];
            [self.contentView addSubview:numView];
            x -= 10.0f;
            remaining /= 10;
        }
    }
}

@end
