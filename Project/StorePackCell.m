//
//  StorePackCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StorePackCell.h"

// The app's UI font name (Ghidra: FUN_0005ef9c — a shared font-name helper).
extern NSString *AppFontName(void);

@implementation StorePackCell

// @ 0x6ed4c — disclosure cell with a shadowed jacket, name/price/purchased labels
// (font auto-shrinks to fit), and new / arcade / chara marker icons.
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        _bgView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.backgroundView = _bgView;
        self.backgroundView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        // Jacket artwork (10, 8, 88x88) with a soft drop shadow, rasterized.
        _artworkView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 8, 88, 88)];
        _artworkView.layer.shadowOffset = CGSizeMake(1, 1);
        _artworkView.layer.shadowColor = [UIColor blackColor].CGColor;
        _artworkView.layer.shadowOpacity = 0.6f;
        _artworkView.layer.shadowRadius = 2.0f;
        _artworkView.layer.shouldRasterize = YES;

        // Pack name — white, size 16, auto-shrinks to 80%.
        _labelName = [[UILabel alloc] initWithFrame:CGRectMake(110, 12, 200, 20)];
        _labelName.backgroundColor = [UIColor clearColor];
        _labelName.highlightedTextColor = [UIColor whiteColor];
        _labelName.font = [UIFont fontWithName:AppFontName() size:16];
        _labelName.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        _labelName.adjustsFontSizeToFitWidth = YES;
        _labelName.minimumScaleFactor = 0.8f;

        // Price — grey, size 14, under the name.
        _labelPrice = [[UILabel alloc] initWithFrame:CGRectMake(110, 40, 60, 18)];
        _labelPrice.backgroundColor = [UIColor clearColor];
        _labelPrice.textColor = [UIColor colorWithWhite:0.3f alpha:1.0f];
        _labelPrice.highlightedTextColor = [UIColor whiteColor];
        _labelPrice.font = [UIFont fontWithName:AppFontName() size:14];

        // "Purchased" — right-aligned, dim, size 13.
        _labelPurchased = [[UILabel alloc] initWithFrame:CGRectMake(110, 78, 100, 18)];
        _labelPurchased.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _labelPurchased.backgroundColor = [UIColor clearColor];
        _labelPurchased.textColor = [UIColor colorWithWhite:0.4f alpha:1.0f];
        _labelPurchased.highlightedTextColor = [UIColor whiteColor];
        _labelPurchased.font = [UIFont fontWithName:AppFontName() size:13];
        _labelPurchased.textAlignment = NSTextAlignmentRight;

        // Marker icons.
        _newMarker = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"store_new"]];
        _arcadeViewer = [[UIImageView alloc]
            initWithImage:[UIImage imageNamed:@"store_arcade_view_ic"]];
        _charaTicket = [[UIImageView alloc]
            initWithImage:[UIImage imageNamed:@"store_chara_ic"]];

        UIView *cv = self.contentView;
        for (UIView *v in @[ _artworkView, _newMarker, _charaTicket, _arcadeViewer,
                             _labelName, _labelPrice, _labelPurchased ]) {
            [cv addSubview:v];
        }
    }
    return self;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
