//
//  YearAndMonthPicker.h
//  pop'n rhythmin
//
//  A UIPickerView subclass with two wheels — a year wheel (1900 + row) and a
//  wrapping month wheel — used by the birthday age gate. It is its own data
//  source + delegate; -year / -month return the currently selected values.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (year @
//  0x8f410, numberOfComponentsInPickerView:
//  @ 0x8f030, pickerView:numberOfRowsInComponent: @ 0x8f034,
//  pickerView:widthForComponent:
//  @ 0x8f064, pickerView:didSelectRow:inComponent: @ 0x8f0e4,
//  pickerView:viewForRow:forComponent:reusingView: @ 0x8f180).
//

#import <UIKit/UIKit.h>

/**
 * @brief A two-wheel year and month picker.
 */
@interface YearAndMonthPicker : UIPickerView <UIPickerViewDataSource, UIPickerViewDelegate> {
    int _year;  /**< The selected year, the row index plus 1900. */
    int _month; /**< The selected month, 1..12. */
    /** The month-wheel row titles, built in -init and pre-repeated so the wheel wraps. */
    NSArray *monthArr;
}

/**
 * @brief The currently selected year.
 * @return The year.
 * @ghidraAddress 0x8f410
 */
- (int)year;
/**
 * @brief The currently selected month.
 * @return The month, 1..12.
 */
- (int)month;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
