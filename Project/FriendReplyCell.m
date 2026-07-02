//
//  FriendReplyCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "FriendReplyCell.h"

@implementation FriendReplyCell {
    BOOL _isOS7;
    int _imgCharaX, _imgPlayerNameX, _dateX, _btnYesX, _btnNoX;
}

// @ 0xa9150 — record the chara / name / date / yes / no subview x offsets (they shift
// on iOS 7).
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    _isOS7 = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;
    if (!_isOS7) {
        _imgCharaX = 0x17; _imgPlayerNameX = 0x46; _dateX = 0x46; _btnYesX = 0xd0; _btnNoX = 0x85;
    } else {
        _imgCharaX = 0x19; _imgPlayerNameX = 0x48; _dateX = 0x48; _btnYesX = 0xe1; _btnNoX = 0x96;
    }
    return self;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
