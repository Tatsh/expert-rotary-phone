//
//  StoreTableCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreTableCell.h"

#import "StorePackView.h"

@implementation StoreTableCell

// @ 0x527b4 — white cell + content view, holding two StorePackView halves (the VC
// frames + fills them per row).
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
        self.contentView.backgroundColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
        _leftPackView = [[StorePackView alloc] initWithFrame:CGRectZero];
        _rightPackView = [[StorePackView alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:_leftPackView];
        [self.contentView addSubview:_rightPackView];
    }
    return self;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
