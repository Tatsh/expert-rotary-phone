//
//  YearAndMonthPicker.m
//  pop'n rhythmin
//
//  See YearAndMonthPicker.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. This file covers the data-source / delegate and the selection
//  accessors; the ~4.6 KB -init (which builds the pre-repeated monthArr and
//  picks the current year/month as the default selection) is a separate
//  reconstruction piece (tracked in HANDOFF.md).
//

#import "YearAndMonthPicker.h"

@implementation YearAndMonthPicker

// @ 0x8ee50 — wire self as its own data source + delegate, build the wrapping
// month list (12 months repeated 14 times = 168 rows so the wheel scrolls
// endlessly), and default the selection to January 2000 (year row 100 -> 1900 +
// 100; month row 84 -> the middle band).
// @complete
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        self.delegate = self;
        self.dataSource = self;
        self.backgroundColor = [UIColor clearColor];

        NSMutableArray *months = [NSMutableArray arrayWithCapacity:168];
        monthArr = months; // strong ivar under ARC — retained on assignment
        for (int rep = 0; rep < 14; rep++) {
            for (int m = 1; m <= 12; m++) {
                // Single digits get one extra leading space so the numbers align in the
                // wheel: "     %d月" (5 spaces) for 1..9, "    %d月" (4 spaces)
                // for 10..12.
                NSString *fmt = (m <= 9) ? @"     %d月" : @"    %d月";
                [months addObject:[NSString stringWithFormat:fmt, m]];
            }
        }
    }
    [self selectRow:100 inComponent:0 animated:NO]; // year 2000
    [self selectRow:84 inComponent:1 animated:NO];  // month wheel centre band (January)
    _year = 2000;
    _month = 1;
    return self;
}

// @ 0x8f410 / 0x8f424 — the selected values (kept up to date by
// -pickerView:didSelectRow:).
// @complete
- (int)year {
    return _year;
} // @ 0x8f410
- (int)month {
    return _month;
} // @ 0x8f424

// @ 0x8f030 — a year wheel and a month wheel.
// @complete
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 2;
}

// @ 0x8f034 — 200 years on the first wheel; the pre-repeated month list on the
// second.
// @complete
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if (component == 0) {
        return 200;
    }
    if (component == 1) {
        return monthArr.count;
    }
    return 0;
}

// @ 0x8f064 — column widths (narrower pre-iOS 7, where the year column is
// widened).
// @complete
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
    if (UIDevice.currentDevice.systemVersion.floatValue < 7.0f) {
        return (component == 0) ? 105.0f : 75.0f;
    }
    return 85.0f;
}

// @ 0x8f0e4 — recenter the wrapping month wheel to its middle band (so it
// scrolls endlessly), then latch the selected year (row + 1900) and month
// (1..12).
// @complete
- (void)pickerView:(UIPickerView *)pickerView
      didSelectRow:(NSInteger)row
       inComponent:(NSInteger)component {
    int m = (int)[self selectedRowInComponent:1] % 12;
    [self selectRow:(m + 84) inComponent:1 animated:NO]; // 84 = 7 * 12, the middle band
    _year = (int)[self selectedRowInComponent:0] + 1900;
    _month = m + 1;
}

// @ 0x8f180 — a per-row label: " YYYY" for the year wheel, the month title for
// the month wheel; black HelveticaNeue-Bold 18, white background on iOS 7+
// (clear before).
// @complete
- (UIView *)pickerView:(UIPickerView *)pickerView
            viewForRow:(NSInteger)row
          forComponent:(NSInteger)component
           reusingView:(UIView *)view {
    UILabel *label = [[UILabel alloc] init];
    label.textColor = [UIColor blackColor];
    label.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:18.0f];

    const BOOL modern = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;
    label.backgroundColor = modern ? [UIColor whiteColor] : [UIColor clearColor];

    CGFloat width;
    if (component == 1) {
        label.text = monthArr[row];
        width = modern ? 85.0f : 75.0f;
    } else if (component == 0) {
        // Year label: "   %ld年" (3 spaces) on iOS 7+, "     %ld年" (5 spaces)
        // before.
        NSString *yfmt = modern ? @"   %ld年" : @"     %ld年";
        label.text = [NSString stringWithFormat:yfmt, (long)((int)row + 1900)];
        width = modern ? 85.0f : 105.0f;
    } else {
        return label;
    }
    label.frame = CGRectMake(0.0f, 0.0f, width, 44.0f);
    return label;
}

// dealloc @ 0x8efe4 — ARC-omitted (released only the strong monthArr ivar; ARC
// synthesizes it).

@end
