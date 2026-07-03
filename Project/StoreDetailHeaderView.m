//
//  StoreDetailHeaderView.m
//  pop'n rhythmin
//
//  See StoreDetailHeaderView.h. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithFrame: @ 0x73a0c, loadPackInfo: @ 0x740d4, setArtwork: @ 0x74400, buttonPurchase @
//  0x74564). The header hosts the pack jacket (+ a faded reflection), the pack name/comment, the
//  buy button and a "NEW" marker. Some frame origins are bounds-relative and NEON-spilled in the
//  binary; reconstructed with the byte-verified sizes and best-effort offsets (the header self-
//  sizes in loadPackInfo:, so the initial origins are refined there).
//

#import "StoreDetailHeaderView.h"
#import "StorePackInfo.h"

// The stretchable button-background font helper the binary uses (FUN_0005ef9c) resolves to the
// pack font "DFSoGei-W5-WIN-RKSJ-H".
static NSString *const kHeaderFont = @"DFSoGei-W5-WIN-RKSJ-H";

@implementation StoreDetailHeaderView {
    UIImageView *m_BgView;                 // stretchable panel background
    UIImageView *m_ArtworkView;            // pack jacket (80x80)
    UIImageView *m_ReflectionArtworkView;  // faded reflection under the jacket
    UILabel *m_LabelName;                  // pack name (2 lines, grows to fit)
    UILabel *m_LabelComment;               // pack description (grows to fit; hidden if empty)
    UIButton *m_ButtonPurchase;            // the buy / INSTALLED button
    UIImageView *m_NewMarker;              // "NEW" badge (hidden unless packInfo.isNew)
}

// @ 0x74564 — the buy button (the controller titles it + wires its tap).
- (UIButton *)buttonPurchase {
    return m_ButtonPurchase;
}

// @ 0x74544 — the pack name label.
- (UILabel *)labelName {
    return m_LabelName;
}

// @ 0x74554 — the pack description label.
- (UILabel *)labelComment {
    return m_LabelComment;
}

// @ 0x73a0c — build the header subviews.
- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self == nil) {
        return self;
    }

    // Stretchable background filling the header.
    m_BgView = [[UIImageView alloc] initWithFrame:self.bounds];
    [m_BgView setImage:[[UIImage imageNamed:@"store_pack_bg_0"]
        stretchableImageWithLeftCapWidth:4 topCapHeight:4]];
    m_BgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; // 0x12
    [self addSubview:m_BgView];

    // Pack jacket + its faded reflection.
    m_ArtworkView = [[UIImageView alloc] initWithFrame:CGRectMake(8.0f, 8.0f, 80.0f, 80.0f)];
    [m_ArtworkView setImage:[UIImage imageNamed:@"store_jacket_160"]];
    [self addSubview:m_ArtworkView];

    m_ReflectionArtworkView =
        [[UIImageView alloc] initWithFrame:CGRectMake(8.0f, 88.0f, 80.0f, 16.0f)];
    m_ReflectionArtworkView.alpha = 0.4f;   // 0x3ecccccd
    [self addSubview:m_ReflectionArtworkView];

    // Pack name (2 lines, word-wrapped, DFSoGei 18). Origin is bounds-relative in the binary.
    m_LabelName = [[UILabel alloc] initWithFrame:CGRectMake(96.0f, 8.0f, 214.0f, 40.0f)];
    m_LabelName.backgroundColor = [UIColor clearColor];
    m_LabelName.numberOfLines = 2;
    m_LabelName.lineBreakMode = NSLineBreakByWordWrapping;
    m_LabelName.font = [UIFont fontWithName:kHeaderFont size:18.0f];
    [self addSubview:m_LabelName];

    // Pack comment (grows to fit, DFSoGei 12).
    m_LabelComment = [[UILabel alloc] initWithFrame:CGRectMake(96.0f, 60.0f, 15.0f, 102.0f)];
    m_LabelComment.backgroundColor = [UIColor clearColor];
    m_LabelComment.numberOfLines = 0;
    m_LabelComment.lineBreakMode = NSLineBreakByWordWrapping;
    m_LabelComment.font = [UIFont fontWithName:kHeaderFont size:12.0f];
    m_LabelComment.autoresizingMask = UIViewAutoresizingFlexibleWidth;   // 2
    [self addSubview:m_LabelComment];

    // Buy button: three stretchable states, white shadowed title.
    m_ButtonPurchase = [UIButton buttonWithType:UIButtonTypeCustom];
    m_ButtonPurchase.frame = CGRectMake(96.0f, 63.0f, 120.0f, 25.0f);
    m_ButtonPurchase.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;   // 1
    [m_ButtonPurchase setBackgroundImage:[[UIImage imageNamed:@"store_btn_normal_1"]
        stretchableImageWithLeftCapWidth:6 topCapHeight:6] forState:UIControlStateNormal];
    [m_ButtonPurchase setBackgroundImage:[[UIImage imageNamed:@"store_btn_clicked_1"]
        stretchableImageWithLeftCapWidth:6 topCapHeight:6] forState:UIControlStateHighlighted];
    [m_ButtonPurchase setBackgroundImage:[[UIImage imageNamed:@"store_btn_disabled"]
        stretchableImageWithLeftCapWidth:6 topCapHeight:6] forState:UIControlStateDisabled];
    m_ButtonPurchase.adjustsImageWhenDisabled = NO;
    m_ButtonPurchase.titleLabel.textColor = [UIColor whiteColor];
    m_ButtonPurchase.titleLabel.font = [UIFont fontWithName:kHeaderFont size:15.0f];
    m_ButtonPurchase.titleLabel.shadowOffset = CGSizeMake(0, -1.0f);
    [m_ButtonPurchase setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [m_ButtonPurchase setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.6f]
                                 forState:UIControlStateNormal];
    [m_ButtonPurchase setTitleColor:[UIColor colorWithWhite:0.62f alpha:1.0f]
                           forState:UIControlStateDisabled];
    [m_ButtonPurchase setTitleShadowColor:[UIColor colorWithWhite:1.0f alpha:0.6f]
                                 forState:UIControlStateDisabled];
    m_ButtonPurchase.exclusiveTouch = YES;
    [self addSubview:m_ButtonPurchase];

    // "NEW" badge.
    m_NewMarker = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"store_new"]];
    [self addSubview:m_NewMarker];

    return self;
}

// @ 0x740d4 — fill the header from the pack and self-size the name/comment labels + the header.
- (void)loadPackInfo:(StorePackInfo *)packInfo {
    // Name: grow the label to fit up to 214x50, keep its origin.
    NSString *name = [packInfo packName];
    CGSize nameSize = name ? [name sizeWithFont:m_LabelName.font
                              constrainedToSize:CGSizeMake(214.0f, 50.0f)
                                  lineBreakMode:m_LabelName.lineBreakMode]
                           : CGSizeZero;
    CGRect nf = m_LabelName.frame;
    m_LabelName.frame = CGRectMake(nf.origin.x, nf.origin.y, 214.0f, nameSize.height);
    m_LabelName.text = name;

    // Comment: hidden when empty, else grow to fit up to 290x120.
    CGFloat bottom;
    NSString *comment = [packInfo comment];
    if (comment == nil) {
        m_LabelComment.hidden = YES;
        bottom = 110.0f;   // 0x42dc0000
    } else {
        CGSize cSize = [comment sizeWithFont:m_LabelComment.font
                           constrainedToSize:CGSizeMake(290.0f, 120.0f)
                               lineBreakMode:m_LabelComment.lineBreakMode];
        CGRect cf = m_LabelComment.frame;
        m_LabelComment.frame = CGRectMake(cf.origin.x, cf.origin.y, 290.0f, cSize.height);
        m_LabelComment.text = comment;
        m_LabelComment.hidden = NO;
        bottom = cf.origin.y + cSize.height;
    }

    // Resize the header to enclose its content.
    CGRect hf = self.frame;
    self.frame = CGRectMake(hf.origin.x, hf.origin.y, hf.size.width, bottom);

    m_NewMarker.hidden = ![packInfo isNew];
}

// @ 0x74400 — set the jacket, and build a faded reflection beneath it.
- (void)setArtwork:(UIImage *)image {
    if (image == nil) {
        return;
    }
    [m_ArtworkView setImage:image];
    // The binary builds a scaled, vertically-flipped reflection (FUN_0005bf5c); best-effort here:
    // reuse the jacket in the low-alpha reflection view.
    [m_ReflectionArtworkView setImage:image];
}

// dealloc @ 0x7447c — ARC-omitted (released object ivars only).

@end
