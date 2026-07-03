//
//  RecommendListCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RecommendListCell.h"

#import "AppFont.h"
#import "neEngineBridge.h"
// TODO(dep): UserSettingData is reconstructed at Game/Data/Save/UserSettingData.h but
// does not yet declare the class method +lastRecommendViewTimeString used below.
#import "Game/Data/Save/UserSettingData.h"

// The NSValue payload getValue: fills for a recommend row. The leading record id is
// unused by the cell; the four object fields drive the thumbnail, name, date and player.
typedef struct {
    int recordId;
    NSString *__unsafe_unretained imageURL;     // pack thumbnail source
    NSString *__unsafe_unretained packName;
    NSString *__unsafe_unretained dateString;
    NSString *__unsafe_unretained playerName;
} RecommendRowValue;

@implementation RecommendListCell {
    BOOL _isOS7;
    int _imgPackX, _dateX, _playerNameX;
    UIImageView *_bgImageView;      // frirec_base_push backdrop (backgroundView on phone)
    UIImageView *_packImageView;    // async pack thumbnail (hidden until loaded)
    UILabel *_packNameLbl;
    UILabel *_dateLbl;
    UILabel *_playerNameLbl;
    UIImageView *_newMarkImgView;   // "NEW" badge
    ImageDownloader *_downloader;   // in-flight thumbnail download
}

// @ 0xbd418 — record the pack-image / date / player-name x offsets (0 on iOS 6).
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    _isOS7 = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;
    if (!_isOS7) {
        _imgPackX = 0; _dateX = 0; _playerNameX = 0;
    } else {
        _imgPackX = 3; _dateX = 5; _playerNameX = 0xc;
    }
    return self;
}

// @ 0xbd518 — cancel the in-flight thumbnail download (real work: kept). ARC releases
// the object ivars.
- (void)dealloc {
    if (_downloader != nil) {
        [_downloader cancelDownload];
    }
}

// @ 0xbd578 — build the row's subviews (once each) from an NSValue-wrapped record and
// start the pack-thumbnail download. On iPad the base x-offset shifts (14 pre-iOS 7,
// 20 on iOS 7+); on iPhone it is 0.
- (void)setRecommendData:(NSValue *)recommendValue {
    RecommendRowValue v;
    [recommendValue getValue:&v];

    BOOL isPad = neSceneManager::isPadDisplay();
    int baseX = 0;
    if (isPad) {
        baseX = (UIDevice.currentDevice.systemVersion.floatValue < 7.0f) ? 14 : 20;
    }

    // Backdrop.
    if (_bgImageView == nil) {
        _bgImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        UIImage *bg = [UIImage imageNamed:@"frirec_base_push"];
        [_bgImageView setImage:bg];
        CGFloat bgX;
        if (!isPad) {
            bgX = 0.0f;
        } else if (UIDevice.currentDevice.systemVersion.floatValue >= 7.0f) {
            bgX = baseX + 2;
        } else {
            bgX = baseX;
        }
        [_bgImageView setFrame:CGRectMake(bgX, 0.0f, bg.size.width, bg.size.height)];
        self.backgroundColor = [UIColor clearColor];
        if (!isPad) {
            self.backgroundView = _bgImageView;
        } else {
            [self.contentView addSubview:_bgImageView];
        }
    }

    // Pack thumbnail + its downloader.
    if (_packImageView == nil) {
        _packImageView = [[UIImageView alloc] initWithFrame:CGRectMake(_imgPackX + baseX + 8,
                                                                       7.0f, 44.0f, 44.0f)];
        [_packImageView setHidden:YES];
        [self.contentView addSubview:_packImageView];

        _downloader = [[ImageDownloader alloc] init];
        [_downloader setImageURL:v.imageURL];
        [_downloader setDelegate:self];
        [_downloader startDownload];
    }

    // Pack name.
    if (_packNameLbl == nil) {
        _packNameLbl = [[UILabel alloc] init];
        _packNameLbl.backgroundColor = [UIColor clearColor];
        _packNameLbl.textColor = [UIColor colorWithRed:93.0f / 255.0f green:88.0f / 255.0f
                                                  blue:84.0f / 255.0f alpha:1.0f];
        _packNameLbl.highlightedTextColor = [UIColor whiteColor];
        _packNameLbl.font = [UIFont fontWithName:AppFontName() size:18.0f];
        _packNameLbl.textAlignment = NSTextAlignmentCenter;
        _packNameLbl.adjustsFontSizeToFitWidth = YES;
        _packNameLbl.minimumScaleFactor = 0.6f;
        _packNameLbl.text = v.packName;
        _packNameLbl.frame = CGRectMake(baseX + 0x3b, 6.0f, 163.0f, 22.0f);
        [self.contentView addSubview:_packNameLbl];
    }

    // Recommend date.
    if (_dateLbl == nil) {
        _dateLbl = [[UILabel alloc] init];
        _dateLbl.backgroundColor = [UIColor clearColor];
        _dateLbl.textColor = [UIColor colorWithRed:93.0f / 255.0f green:88.0f / 255.0f
                                              blue:84.0f / 255.0f alpha:1.0f];
        _dateLbl.highlightedTextColor = [UIColor whiteColor];
        _dateLbl.font = [UIFont fontWithName:AppFontName() size:14.0f];
        if (neSceneManager::isPadDisplay()) {
            _dateLbl.font = [UIFont fontWithName:AppFontName() size:12.0f];
        }
        _dateLbl.textAlignment = NSTextAlignmentLeft;
        _dateLbl.adjustsFontSizeToFitWidth = YES;
        _dateLbl.minimumScaleFactor = 0.8f;
        _dateLbl.text = v.dateString;
        _dateLbl.frame = CGRectMake(_dateX + baseX + 0x3b, 34.0f, 320.0f, 20.0f);
        [self.contentView addSubview:_dateLbl];
    }

    // Recommending player's name.
    if (_playerNameLbl == nil) {
        _playerNameLbl = [[UILabel alloc] init];
        _playerNameLbl.backgroundColor = [UIColor clearColor];
        _playerNameLbl.textColor = [UIColor colorWithRed:93.0f / 255.0f green:88.0f / 255.0f
                                                    blue:84.0f / 255.0f alpha:1.0f];
        _playerNameLbl.highlightedTextColor = [UIColor whiteColor];
        _playerNameLbl.font = [UIFont fontWithName:AppFontName() size:13.0f];
        _playerNameLbl.textAlignment = NSTextAlignmentLeft;
        _playerNameLbl.adjustsFontSizeToFitWidth = YES;
        _playerNameLbl.minimumScaleFactor = 10.0f;   // matches the binary literal (0x41200000)
        _playerNameLbl.text = v.playerName;
        CGFloat pnX = baseX + _playerNameX + (neSceneManager::isPadDisplay() ? 0xbf : 0xc4);
        _playerNameLbl.frame = CGRectMake(pnX, 34.0f, 90.0f, 20.0f);
        [self.contentView addSubview:_playerNameLbl];
    }

    // "NEW" badge — only when this row's date is newer than the last recommend-list view.
    if (_newMarkImgView == nil) {
        NSString *lastView = [UserSettingData lastRecommendViewTimeString];
        if (lastView != nil && [lastView compare:v.dateString] == NSOrderedAscending) {
            UIImage *newImg = [UIImage imageNamed:@"frirec_new"];
            _newMarkImgView = [[UIImageView alloc] initWithFrame:CGRectMake(baseX + 0xf0, 8.0f,
                                                                            newImg.size.width,
                                                                            newImg.size.height)];
            [_newMarkImgView setImage:newImg];
            [self.contentView addSubview:_newMarkImgView];
        }
    }
}

// @ 0xbe1d0 — thumbnail arrived: show it in the pack image view, drop the downloader.
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    UIImage *image = [downloader getImage];
    if (image != nil) {
        [_packImageView setImage:image];
        [_packImageView setHidden:NO];
    }
    _downloader = nil;
}

// @ 0xbe244 — thumbnail failed: just drop the downloader (image view stays hidden).
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    _downloader = nil;
}

@end
