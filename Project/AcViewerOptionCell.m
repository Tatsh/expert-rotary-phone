//
//  AcViewerOptionCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "AcViewerOptionCell.h"

#import "AppFont.h"
#import "UserSettingData.h"

@implementation AcViewerOptionCell {
    UILabel *_optionKindLbl;   // left "HI-SPEED / POP-KUN / …" caption
    UILabel *_optionDetailLbl; // right current-value readout
}

// @ 0x65480 — plain non-selectable cell; content set by the VC on reuse.
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

// dealloc @ 0x654c8 — ARC-omitted (releases ivars only; synthesized by ARC).

// @ 0x654f4 — rebuild the row for one option kind: a rounded-corner background
// image (top / bar / under depending on the row's position), a left caption
// label and a right value label showing the player's stored setting for that
// kind.
- (void)setData:(int)optionKind {
    [_optionKindLbl removeFromSuperview];
    _optionKindLbl = nil;
    [_optionDetailLbl removeFromSuperview];
    _optionDetailLbl = nil;

    float osVersion = UIDevice.currentDevice.systemVersion.floatValue;

    // Background image varies with the row's position in the group.
    NSString *bgName;
    switch (optionKind) {
    case 0:
        bgName = @"acv_custom_option_top";
        break; // first row
    case 3:
        bgName = @"acv_custom_option_under";
        break; // last row
    default:
        bgName = @"acv_custom_option_bar";
        break; // 1, 2 (middle rows)
    }
    UIImage *bg = [UIImage imageNamed:bgName];
    UIImageView *bgView = [[UIImageView alloc] initWithImage:bg];
    bgView.frame = CGRectMake(0.0f, 0.0f, bg.size.width, bg.size.height);
    self.backgroundView = bgView;
    self.backgroundColor = [UIColor clearColor];

    // Left caption label.
    _optionKindLbl = [[UILabel alloc] init];
    _optionKindLbl.backgroundColor = [UIColor clearColor];
    _optionKindLbl.textColor = [UIColor colorWithRed:48.0f / 255.0f
                                               green:48.0f / 255.0f
                                                blue:48.0f / 255.0f
                                               alpha:1.0f];
    _optionKindLbl.highlightedTextColor = [UIColor whiteColor];
    _optionKindLbl.font = [UIFont fontWithName:AppFontName() size:17.0f];
    _optionKindLbl.textAlignment = NSTextAlignmentLeft;
    _optionKindLbl.adjustsFontSizeToFitWidth = YES;
    [_optionKindLbl setMinimumScaleFactor:10.0f]; // raw 0x41200000 (legacy
                                                  // minimum-font-size value)
    _optionKindLbl.frame = CGRectMake(50.0f, 9.0f, 100.0f, 26.0f);
    [self.contentView addSubview:_optionKindLbl];
    switch (optionKind) {
    case 0:
        _optionKindLbl.text = @"HI-SPEED";
        break;
    case 1:
        _optionKindLbl.text = @"POP-KUN";
        break;
    case 2:
        _optionKindLbl.text = @"HID-SUD";
        break;
    case 3:
        _optionKindLbl.text = @"RAN-MIR";
        break;
    }

    // Right value label.
    _optionDetailLbl = [[UILabel alloc] init];
    _optionDetailLbl.backgroundColor = [UIColor clearColor];
    _optionDetailLbl.textColor = [UIColor colorWithRed:120.0f / 255.0f
                                                 green:120.0f / 255.0f
                                                  blue:120.0f / 255.0f
                                                 alpha:1.0f];
    _optionDetailLbl.highlightedTextColor = [UIColor whiteColor];
    _optionDetailLbl.font = [UIFont fontWithName:AppFontName() size:14.0f];
    _optionDetailLbl.textAlignment = NSTextAlignmentRight;
    _optionDetailLbl.adjustsFontSizeToFitWidth = YES;
    [_optionDetailLbl setMinimumScaleFactor:10.0f]; // raw 0x41200000
    _optionDetailLbl.frame = CGRectMake(osVersion < 7.0f ? 155.0f : 172.0f, 8.0f, 100.0f, 26.0f);
    [self.contentView addSubview:_optionDetailLbl];

    NSString *value = nil;
    switch (optionKind) {
    case 0: {
        static NSString *const kHiSpeed[] = {@"OFF",
                                             @"HI-SP 1.5",
                                             @"HI-SP 2.0",
                                             @"HI-SP 2.5",
                                             @"HI-SP 3.0",
                                             @"HI-SP 3.5",
                                             @"HI-SP 4.0",
                                             @"HI-SP 4.5",
                                             @"HI-SP 5.0",
                                             @"HI-SP 5.5",
                                             @"HI-SP 6.0"};
        value = kHiSpeed[[UserSettingData acvHiSpeed]];
        break;
    }
    case 1: {
        static NSString *const kPopKun[] = {@"OFF", @"BEAT POP"};
        value = kPopKun[[UserSettingData acvPopKun]];
        break;
    }
    case 2: {
        static NSString *const kHidSud[] = {@"OFF", @"HIDDEN", @"SUDDEN", @"HID-SUD"};
        value = kHidSud[[UserSettingData acvHidSud]];
        break;
    }
    case 3: {
        static NSString *const kRanMir[] = {@"OFF", @"RANDOM", @"MIRROR", @"S-RAN"};
        value = kRanMir[[UserSettingData acvRanMir]];
        break;
    }
    }
    // A trailing space pads the right-aligned value away from the rounded edge.
    _optionDetailLbl.text = [value stringByAppendingString:@" "];
}

@end
