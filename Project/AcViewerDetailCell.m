//
//  AcViewerDetailCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "AcViewerDetailCell.h"

#import "AppFont.h"
#import "UserSettingData.h"

@implementation AcViewerDetailCell {
    int _index;                   // this row's value index within the option kind
    UILabel *_optionLbl;          // left value caption (not retained; lives in the view tree)
    UIImageView *_checkImageView; // right check mark for the selected value (idem)
}

@synthesize optionName = _optionName;
@synthesize optionKind = _optionKind;

// @ 0x5b620 — a plain non-selectable cell; its content is filled by the VC on reuse.
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

// dealloc @ 0x5b668 — ARC-omitted (object ivars only).

// @ 0x5b694 — bind one value row of an option kind: pick the rounded-group background slice
// (top for the first row, under for the last, bar in between — "last" depends on how many
// values the kind has), draw the option name on the left, and place a check mark on the right
// of whichever row is the player's current stored value for this kind.
- (void)setData:(int)index {
    _index = index;

    [_optionLbl removeFromSuperview];
    _optionLbl = nil;
    [_checkImageView removeFromSuperview];
    _checkImageView = nil;

    float osVersion = UIDevice.currentDevice.systemVersion.floatValue;

    // The last row index for this option kind (HI-SPEED spans many; the rest are short).
    int lastIndex;
    switch (_optionKind) {
        case 1:  lastIndex = 1;  break;  // POP-KUN
        case 2:  lastIndex = 3;  break;  // HID-SUD
        case 3:  lastIndex = 3;  break;  // RAN-MIR
        default: lastIndex = 10; break;  // HI-SPEED (kind 0) and anything else
    }

    // Rounded-group background slice by row position.
    NSString *bgName;
    if (index == 0) {
        bgName = @"acv_custom_option_top";
    } else if (index == lastIndex) {
        bgName = @"acv_custom_option_under";
    } else {
        bgName = @"acv_custom_option_bar";
    }
    UIImage *bg = [UIImage imageNamed:bgName];
    UIImageView *bgView = [[UIImageView alloc] initWithImage:bg];
    bgView.frame = CGRectMake(0.0f, 0.0f, bg.size.width, bg.size.height);
    self.backgroundView = bgView;
    self.backgroundColor = [UIColor clearColor];

    // Left value caption.
    _optionLbl = [[UILabel alloc] init];
    _optionLbl.backgroundColor = [UIColor clearColor];
    _optionLbl.textColor = [UIColor colorWithRed:48.0f / 255.0f green:48.0f / 255.0f blue:48.0f / 255.0f alpha:1.0f];
    _optionLbl.highlightedTextColor = [UIColor whiteColor];
    _optionLbl.font = [UIFont fontWithName:AppFontName() size:17.0f];
    _optionLbl.textAlignment = NSTextAlignmentLeft;
    _optionLbl.adjustsFontSizeToFitWidth = YES;
    [_optionLbl setMinimumScaleFactor:10.0f];  // raw 0x41200000 (legacy minimum-font-size value)
    _optionLbl.frame = CGRectMake(50.0f, 9.0f, 100.0f, 26.0f);
    [self.contentView addSubview:_optionLbl];
    _optionLbl.text = _optionName;

    // The player's currently-selected value for this option kind (drives the check mark).
    int selected = 0;
    switch (_optionKind) {
        case 0: selected = [UserSettingData acvHiSpeed]; break;
        case 1: selected = [UserSettingData acvPopKun];  break;
        case 2: selected = [UserSettingData acvHidSud];  break;
        case 3: selected = [UserSettingData acvRanMir];  break;
        default: break;
    }
    NSString *checkName = (selected == index) ? @"m_sort_check_01" : @"m_sort_check_00";
    UIImage *checkImg = [UIImage imageNamed:checkName];
    _checkImageView = [[UIImageView alloc]
        initWithFrame:CGRectMake(osVersion < 7.0f ? 228.0f : 245.0f, 7.0f,
                                 checkImg.size.width, checkImg.size.height)];
    [_checkImageView setImage:checkImg];
    [self.contentView addSubview:_checkImageView];
}

@end
