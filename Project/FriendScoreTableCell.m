//
//  FriendScoreTableCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "FriendScoreTableCell.h"

@implementation FriendScoreTableCell {
    BOOL _isOS7;
    int _imgYouX, _imgFrameX, _imgFrame10X, _imgFrame01X, _imgOrderX, _imgCharaX;
    int _imgPlayerNameX, _imgScoreBaseX, _imgScoreX, _imgRankX, _imgFullComboX;
}

// @ 0xae06c — record the full row layout x offsets (iOS 6 vs 7).
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    _isOS7 = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;
    if (!_isOS7) {
        _imgYouX = 0xe8; _imgFrameX = 0xd; _imgFrame10X = 0xe; _imgFrame01X = 0x1d;
        _imgOrderX = 0x2b; _imgCharaX = 0x2b; _imgPlayerNameX = 0x5b; _imgScoreBaseX = 0x58;
        _imgScoreX = 10; _imgRankX = 0xde; _imgFullComboX = 0xe4;
    } else {
        _imgYouX = 0xfb; _imgFrameX = 0x14; _imgFrame10X = 0x15; _imgFrame01X = 0x24;
        _imgOrderX = 0x32; _imgCharaX = 0x32; _imgPlayerNameX = 0x62; _imgScoreBaseX = 0x5f;
        _imgScoreX = 0x11; _imgRankX = 0xea; _imgFullComboX = 0xf0;
    }
    return self;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
