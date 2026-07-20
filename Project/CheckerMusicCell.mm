//
//  CheckerMusicCell.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  .mm because init/-setData: reach the C++ engine bridge
//  (neSceneManager::isPadDisplay()).
//

#import "CheckerMusicCell.h"

#import "AppFont.h"         // AppFontName() == getFontNameDFSoGei()
#import "ArcadeScoreData.h" // in-project dependency (Game/Data/Save); no stub needed
#import "neEngineBridge.h"

@implementation CheckerMusicCell {
    ArcadeScoreData *_scoreData;
    UIImageView *_bgImg; // iPad-only: banner held as a plain subview
    UILabel *_dateLbl;
    UILabel *_titleLbl;
    UILabel *_genreLbl;
    BOOL isOS7; // cached in init: systemVersion >= 7.0
    int bgX;    // banner x offset (iPad path)
    int dateX;  // date label x offset
    int titleX; // title label x offset
    int genreX; // genre label x offset
}

// @ 0xd1d28 — cache the OS flag and resolve the per-device/OS x offsets once.
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    isOS7 = [[UIDevice currentDevice].systemVersion floatValue] >= 7.0f;
    BOOL isPad = neSceneManager::isPadDisplay();
    if (!isPad) {
        bgX = 0;
        if (!isOS7) {
            dateX = 6;
            titleX = genreX = 105;
        } else {
            dateX = 18;
            titleX = genreX = 117;
        }
    } else if (!isOS7) {
        bgX = 0;
        dateX = 2;
        titleX = genreX = 108;
    } else {
        bgX = 11;
        dateX = 13;
        titleX = genreX = 124;
    }
    return self;
}

// dealloc @ 0xd1ea0 — ARC-omitted (super-only; frees no C memory).

// @ 0xd1ecc — tear down recycled subviews, install the banner background
// (device/OS dependent), then rebuild the date / title / genre labels from the
// score record.
- (void)setData:(ArcadeScoreData *)scoreData {
    _scoreData = scoreData;

    // Reuse cleanup.
    [_dateLbl removeFromSuperview];
    _dateLbl = nil;
    [_titleLbl removeFromSuperview];
    _titleLbl = nil;
    [_genreLbl removeFromSuperview];
    _genreLbl = nil;
    [_bgImg removeFromSuperview];
    _bgImg = nil;

    UIImage *baseImg = [UIImage imageNamed:@"ppc_mlist_base"];
    BOOL isPad = neSceneManager::isPadDisplay();

    if (!isPad) {
        UIImageView *bg = [[UIImageView alloc] initWithFrame:self.bounds];
        [bg setImage:baseImg];
        if (!isOS7) {
            // Pre-iOS 7 phone: banner is the cell background directly.
            [bg setFrame:CGRectMake(0.0f, 0.0f, baseImg.size.width, baseImg.size.height)];
            self.backgroundView = bg;
        } else {
            // iOS 7+ phone: center the banner inside a full-width (59pt tall)
            // background view.
            UIView *container = [[UIView alloc]
                initWithFrame:CGRectMake(0.0f, 0.0f, self.bounds.size.width, 59.0f)];
            CGFloat cw = container.frame.size.width;
            [bg setFrame:CGRectMake((cw - baseImg.size.width) * 0.5f,
                                    0.0f,
                                    baseImg.size.width,
                                    container.frame.size.height)];
            [container addSubview:bg];
            self.backgroundView = container;
        }
    } else {
        // iPad: fixed-size banner (300x59) at bgX, kept as a content subview.
        UIImageView *bg = [[UIImageView alloc]
            initWithFrame:CGRectMake(static_cast<CGFloat>(bgX), 0.0f, 300.0f, 59.0f)];
        [bg setImage:baseImg];
        _bgImg = bg;
        [self.contentView addSubview:bg];
    }
    self.backgroundColor = [UIColor clearColor];

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy/MM/dd"];

    // Update-date label (DFSoGei 10, orange, centered).
    _dateLbl = [[UILabel alloc] init];
    _dateLbl.backgroundColor = [UIColor clearColor];
    _dateLbl.textColor = [UIColor colorWithRed:(195.0f / 255.0f)
                                         green:(51.0f / 255.0f)
                                          blue:(1.0f / 255.0f)
                                         alpha:1.0f];
    _dateLbl.highlightedTextColor = [UIColor whiteColor];
    _dateLbl.font = [UIFont fontWithName:AppFontName() size:10.0f];
    _dateLbl.textAlignment = NSTextAlignmentCenter;
    _dateLbl.adjustsFontSizeToFitWidth = YES;
    _dateLbl.minimumScaleFactor = 10.0f; // faithful to binary (0x41200000); out-of-range as shipped
    _dateLbl.text = [df stringFromDate:scoreData.updateDate];
    [_dateLbl setFrame:CGRectMake(static_cast<CGFloat>(dateX), 33.0f, 62.0f, 13.0f)];
    [self.contentView addSubview:_dateLbl];

    // Title label (DFSoGei 14, dark gray, left-aligned).
    _titleLbl = [[UILabel alloc] init];
    _titleLbl.backgroundColor = [UIColor clearColor];
    _titleLbl.textColor = [UIColor colorWithRed:(87.0f / 255.0f)
                                          green:(81.0f / 255.0f)
                                           blue:(76.0f / 255.0f)
                                          alpha:1.0f];
    _titleLbl.highlightedTextColor = [UIColor whiteColor];
    _titleLbl.font = [UIFont fontWithName:AppFontName() size:14.0f];
    _titleLbl.textAlignment = NSTextAlignmentLeft;
    _titleLbl.adjustsFontSizeToFitWidth = YES;
    _titleLbl.minimumScaleFactor = 10.0f; // faithful to binary (0x41200000)
    _titleLbl.text = scoreData.title;
    [_titleLbl setFrame:CGRectMake(static_cast<CGFloat>(titleX), 9.0f, 116.0f, 18.0f)];
    [self.contentView addSubview:_titleLbl];

    // Genre label (DFSoGei 14, near-white, left-aligned).
    _genreLbl = [[UILabel alloc] init];
    _genreLbl.backgroundColor = [UIColor clearColor];
    _genreLbl.textColor = [UIColor colorWithRed:(245.0f / 255.0f)
                                          green:(245.0f / 255.0f)
                                           blue:(245.0f / 255.0f)
                                          alpha:1.0f];
    _genreLbl.highlightedTextColor = [UIColor whiteColor];
    _genreLbl.font = [UIFont fontWithName:AppFontName() size:14.0f];
    _genreLbl.textAlignment = NSTextAlignmentLeft;
    _genreLbl.adjustsFontSizeToFitWidth = YES;
    _genreLbl.minimumScaleFactor = 10.0f; // faithful to binary (0x41200000)
    _genreLbl.text = scoreData.genre;
    [_genreLbl setFrame:CGRectMake(static_cast<CGFloat>(genreX), 33.0f, 116.0f, 18.0f)];
    [self.contentView addSubview:_genreLbl];
}

@end
