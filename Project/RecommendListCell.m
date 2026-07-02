//
//  RecommendListCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RecommendListCell.h"

@implementation RecommendListCell {
    BOOL _isOS7;
    int _imgPackX, _dateX, _playerNameX;
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

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
