//
//  PresentBoxCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "PresentBoxCell.h"
#import "AppFont.h"        // AppFontName / AppMaruFontName
#import "neEngineBridge.h" // neSceneManager::isPadDisplay

// The NSValue payload getValue: fills for a present row. The leading id is
// unused by the cell; the type selects the icon/format, num is the quantity and
// info is the blurb.
typedef struct {
    int presentId;                      // +0  server present id (unused by the cell)
    int type;                           // +4  0 = treasure point, 1 = character ticket
    int num;                            // +8  quantity
    NSString *__unsafe_unretained info; // +0xc one-line description shown in _lblInfo
} PresentData;

@implementation PresentBoxCell {
    PresentData _presentData;
    UIImageView *_imageViewIcon;
    UILabel *_lbl;
    UILabel *_lblInfo;
}

@synthesize getBtn = _getBtn;

// .cxx_construct @ 0x6ed48 — compiler-emitted C++ ivar constructor; not
// hand-written.

// @ 0x6e3ac — non-selectable, clear background, no background view (the gift
// artwork is added by the VC).
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        self.backgroundView = nil;
    }
    return self;
}

// dealloc @ 0x6e438 — ARC-omitted (object ivars only; super-only teardown).
// setSelected:animated: @ 0x6e464 — super-only override, omitted.

// @ 0x6e494 — rebuild the row from an NSValue-wrapped present record: a banner
// sized to its artwork, a treasure/character icon, an amount label, a one-line
// info label and an "acquire" button. Every element is torn down and recreated
// on each call. On iPad the banner is centred in the content view (with a
// pre-iOS 7 nudge) instead of becoming the cell's backgroundView; the "acquire"
// button also shifts left pre-iOS 7.
- (void)setPresentData:(NSValue *)presentData {
    BOOL isPad = neSceneManager::isPadDisplay();
    CGFloat sysVer = UIDevice.currentDevice.systemVersion.floatValue;

    [presentData getValue:&_presentData];

    if (_imageViewIcon != nil) {
        [_imageViewIcon removeFromSuperview];
        _imageViewIcon = nil;
    }
    if (_lbl != nil) {
        [_lbl removeFromSuperview];
        _lbl = nil;
    }
    if (_lblInfo != nil) {
        [_lblInfo removeFromSuperview];
        _lblInfo = nil;
    }
    if (_getBtn != nil) {
        [_getBtn removeFromSuperview];
        _getBtn = nil;
    }

    // Banner background, sized to its artwork.
    UIImageView *banner = [[UIImageView alloc] initWithFrame:self.bounds];
    UIImage *bannerImg = [UIImage imageNamed:@"pbox_banner"];
    [banner setImage:bannerImg];
    [banner setFrame:CGRectMake(0.0f, 0.0f, bannerImg.size.width, bannerImg.size.height)];
    if (!isPad) {
        self.backgroundView = banner;
        self.backgroundColor = [UIColor clearColor];
    } else {
        [self.contentView addSubview:banner];
        banner.center = CGPointMake(170.0f, bannerImg.size.height * 0.5f);
        // Pre-iOS 7 nudged the banner 10pt left (original: recovered vector frame
        // math).
        if (UIDevice.currentDevice.systemVersion.floatValue < 7.0f) {
            CGRect f = banner.frame;
            f.origin.x -= 10.0f;
            banner.frame = f;
        }
    }

    // Treasure / character icon at (29, 8).
    _imageViewIcon = [[UIImageView alloc] initWithFrame:self.bounds];
    UIImage *iconImg = nil;
    if (_presentData.type == 1) {
        iconImg = [UIImage imageNamed:@"pbox_icon_character"];
    } else if (_presentData.type == 0) {
        iconImg = [UIImage imageNamed:@"pbox_icon_treasure_p"];
    }
    [_imageViewIcon setImage:iconImg];
    [_imageViewIcon setFrame:CGRectMake(29.0f, 8.0f, iconImg.size.width, iconImg.size.height)];
    [self.contentView addSubview:_imageViewIcon];

    // Amount label (80, 6, 200, 20) — DFSoGei 12pt, black.
    _lbl = [[UILabel alloc] initWithFrame:CGRectMake(80.0f, 6.0f, 200.0f, 20.0f)];
    _lbl.backgroundColor = [UIColor clearColor];
    _lbl.textColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
    _lbl.highlightedTextColor = [UIColor whiteColor];
    _lbl.font = [UIFont fontWithName:AppFontName() size:12.0f];
    _lbl.adjustsFontSizeToFitWidth = YES;
    _lbl.minimumScaleFactor = 8.0f; // matches the binary literal (0x41000000)
    if (_presentData.type == 1) {
        _lbl.text = [NSString stringWithFormat:@"キャラチケ %d枚", _presentData.num];
    } else if (_presentData.type == 0) {
        _lbl.text = [NSString stringWithFormat:@"トレジャーポイント %dP", _presentData.num];
    }
    [self.contentView addSubview:_lbl];

    // One-line info label (80, 22, 100, 20) — DFMaruGothic 8pt, black.
    _lblInfo = [[UILabel alloc] initWithFrame:CGRectMake(80.0f, 22.0f, 100.0f, 20.0f)];
    _lblInfo.backgroundColor = [UIColor clearColor];
    _lblInfo.textColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
    _lblInfo.highlightedTextColor = [UIColor whiteColor];
    _lblInfo.font = [UIFont fontWithName:AppMaruFontName() size:8.0f];
    _lblInfo.adjustsFontSizeToFitWidth = YES;
    _lblInfo.minimumScaleFactor = 8.0f; // matches the binary literal (0x41000000)
    _lblInfo.text = _presentData.info;
    [self.contentView addSubview:_lblInfo];

    // "Acquire" button, right-aligned at y = 26; x = 191 pre-iOS 7, else 208.
    _getBtn = [[UIButton alloc] init];
    UIImage *btnImg = [UIImage imageNamed:@"pbox_bt_acquis_yes"];
    [_getBtn setBackgroundImage:btnImg forState:UIControlStateNormal];
    CGFloat btnX = (sysVer < 7.0f) ? 191.0f : 208.0f;
    [_getBtn setFrame:CGRectMake(btnX, 26.0f, btnImg.size.width, btnImg.size.height)];
    [self.contentView addSubview:_getBtn];
}

// getBtn @ 0x6ed34 — synthesized atomic getter (reads _getBtn).

@end
