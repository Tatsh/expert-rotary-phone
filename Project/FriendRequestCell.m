//
//  FriendRequestCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "FriendRequestCell.h"

@implementation FriendRequestCell {
    BOOL _isOS7;
    int _imgCharaX;
    int _imgPlayerNameX;
    int _imgDateX;
    int _btnCancelX;
}

// @ 0xb9740 — record the layout x offsets for the chara icon / player name / date /
// cancel button, which shift by ~2 px on iOS 7 vs 6.
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    _isOS7 = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;
    if (!_isOS7) {
        _imgCharaX = 0x17; _imgPlayerNameX = 0x46; _imgDateX = 0x46; _btnCancelX = 0xc6;
    } else {
        _imgCharaX = 0x19; _imgPlayerNameX = 0x48; _imgDateX = 0x48; _btnCancelX = 0xd0;
    }
    return self;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
