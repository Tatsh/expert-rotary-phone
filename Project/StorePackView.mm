//
//  StorePackView.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StorePackView.h"
#import "StorePackInfo.h"
#import "StoreUtil.h"
#import "PurchaseManager.h"
#import "AppFont.h"
#import "neEngineBridge.h"

@implementation StorePackView

@synthesize delegate = m_Delegate;   // delegate @ 0x52784 / setDelegate: @ 0x52794 (synthesized)
@synthesize index = m_Index;         // index @ 0x527a4 (synthesized getter)

// @ 0x51a44 — build the tile. All colour and geometry constants are byte-verified
// from the literal pool and disassembly.
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        // Background image view fills the tile and owns the tap gesture.
        m_BackGroundImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        m_BackGroundImageView.userInteractionEnabled = YES;
        m_BackGroundImageView.exclusiveTouch = YES;
        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [m_BackGroundImageView addGestureRecognizer:tap];

        // Jacket artwork: (15,15,110,110), aspect-fit, faint white fill, 1pt white
        // border, soft black drop shadow, rasterized.
        m_ArtworkImageView =
            [[UIImageView alloc] initWithFrame:CGRectMake(15, 15, 110, 110)];
        m_ArtworkImageView.contentMode = UIViewContentModeScaleAspectFit;
        m_ArtworkImageView.opaque = NO;
        m_ArtworkImageView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.3f];
        CALayer *artLayer = m_ArtworkImageView.layer;
        artLayer.borderWidth = 1.0f;
        artLayer.borderColor = [UIColor whiteColor].CGColor;
        artLayer.shadowOffset = CGSizeMake(2.0f, 2.0f);
        artLayer.shadowColor = [UIColor blackColor].CGColor;
        artLayer.shadowOpacity = 0.6f;
        artLayer.shadowRadius = 2.0f;
        artLayer.shouldRasterize = YES;

        // Name label — right of the jacket.
        // @ 0x51c18: x=0x430c0000=140 (constant), y=0x41400000=12,
        // w=frame.width+literal@0x5204c(0xc3110000=−145), h=0x41a00000=20.
        m_NameLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(140.0f, 12.0f, CGRectGetWidth(frame) - 145.0f, 20.0f)];
        m_NameLabel.backgroundColor = [UIColor clearColor];
        m_NameLabel.font = [UIFont fontWithName:AppFontName() size:17.0f];
        m_NameLabel.textColor = [UIColor colorWithWhite:0.0f alpha:1.0f];
        m_NameLabel.adjustsFontSizeToFitWidth = YES;
        m_NameLabel.minimumScaleFactor = 0.6f;

        // "Purchased" pill — a custom button that is always disabled; it only shows
        // a disabled-state background ("store_btn_disabled.png", 6pt stretchable caps)
        // and the title "購入済み" ("Purchased") — Ghidra CFString @ 0x136bd8.
        m_PurchasedButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *disabledBg = [[UIImage imageNamed:@"store_btn_disabled.png"]
            stretchableImageWithLeftCapWidth:6 topCapHeight:6];
        [m_PurchasedButton setBackgroundImage:disabledBg forState:UIControlStateDisabled];
        m_PurchasedButton.exclusiveTouch = YES;
        m_PurchasedButton.adjustsImageWhenDisabled = NO;
        m_PurchasedButton.titleLabel.textColor = [UIColor colorWithWhite:0.62f alpha:1.0f];
        m_PurchasedButton.titleLabel.font = [UIFont fontWithName:AppFontName() size:15.0f];
        m_PurchasedButton.titleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
        [m_PurchasedButton setTitleColor:[UIColor colorWithWhite:0.62f alpha:1.0f]
                                forState:UIControlStateDisabled];
        [m_PurchasedButton setTitleShadowColor:[UIColor colorWithWhite:1.0f alpha:0.6f]
                                      forState:UIControlStateDisabled];
        [m_PurchasedButton setTitle:@"購入済み"    // "Purchased"
                           forState:UIControlStateDisabled];
        m_PurchasedButton.enabled = NO;
        [m_PurchasedButton sizeToFit];
        // @ 0x51f98 — pad the post-sizeToFit size by (10, 4) then place the button
        // at the tile's bottom-right corner with a 15pt right margin and 5pt bottom
        // margin (0x41200000=10, 0x40800000=4, 0xc1700000=−15, 0xc0a00000=−5).
        {
            CGSize bs = m_PurchasedButton.frame.size;
            CGFloat bw = bs.width  + 10.0f;
            CGFloat bh = bs.height + 4.0f;
            m_PurchasedButton.frame = CGRectMake(CGRectGetWidth(frame)  - bw - 15.0f,
                                                  CGRectGetHeight(frame) - bh -  5.0f,
                                                  bw, bh);
        }

        // Comment label — one-line blurb under the name. (The initialiser adds it as a
        // subview; its construction was folded by the decompiler, so its frame mirrors
        // the name label's column.)
        m_CommentLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(CGRectGetWidth(frame) - 145.0f, 40, 140, 18)];
        m_CommentLabel.backgroundColor = [UIColor clearColor];
        m_CommentLabel.font = [UIFont fontWithName:AppFontName() size:13.0f];
        m_CommentLabel.textColor = [UIColor colorWithWhite:0.0f alpha:1.0f];

        // Price label — width 140, height 32, dim (white 0.196) @ 15pt.
        m_PriceLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(CGRectGetWidth(frame) - 145.0f, 100, 140, 32)];
        m_PriceLabel.backgroundColor = [UIColor clearColor];
        m_PriceLabel.font = [UIFont fontWithName:AppFontName() size:15.0f];
        m_PriceLabel.textColor = [UIColor colorWithWhite:0.196f alpha:1.0f];

        // "New" badge.
        m_NewMarker = [[UIImageView alloc]
            initWithImage:[UIImage imageNamed:@"store_new.png"]];

        // Arcade-viewer badge at (140,77), hidden until a pack has arcade content.
        UIImage *acvImg = [UIImage imageNamed:@"store_arcade_view_ic"];
        m_ArcadeViewerImageView = [[UIImageView alloc] initWithImage:acvImg];
        m_ArcadeViewerImageView.frame =
            CGRectMake(140.0f, 77.0f, acvImg.size.width, acvImg.size.height);
        m_ArcadeViewerImageView.hidden = YES;

        // Chara-ticket badge at (140, below the arcade badge).
        UIImage *charaImg = [UIImage imageNamed:@"store_chara_ic"];
        CGFloat ticketY = CGRectGetMaxY(m_ArcadeViewerImageView.frame);
        m_TicketImageView = [[UIImageView alloc] initWithImage:charaImg];
        m_TicketImageView.frame =
            CGRectMake(140.0f, ticketY, charaImg.size.width, charaImg.size.height);

        // Subview order matches the binary exactly.
        [self addSubview:m_BackGroundImageView];
        [self addSubview:m_ArtworkImageView];
        [self addSubview:m_NameLabel];
        [self addSubview:m_CommentLabel];
        [self addSubview:m_PriceLabel];
        [self addSubview:m_PurchasedButton];
        [self addSubview:m_NewMarker];
        [self addSubview:m_ArcadeViewerImageView];
        [self addSubview:m_TicketImageView];
    }
    return self;
}

// @ 0x5258c — bind a pack model: labels, "new" marker, arcade-viewer marker, and
// the purchased / ticket state (derived live from PurchaseManager).
- (void)loadPackInfo:(StorePackInfo *)packInfo index:(unsigned int)index {
    m_NameLabel.text = [packInfo packName];
    m_CommentLabel.text = [packInfo s_comment];
    m_PriceLabel.text = [packInfo priceString];
    m_NewMarker.hidden = ![packInfo isNew];
    m_ArcadeViewerImageView.hidden = ([packInfo acvNum] < 1);

    NSString *productID = [StoreUtil productIDForPackID:[packInfo packID]];
    BOOL purchased = [[PurchaseManager sharedManager] isPurchased:productID];
    if (purchased) {
        m_PurchasedButton.hidden = NO;
        m_ArcadeViewerImageView.hidden = YES;   // hide arcade marker once purchased
    } else {
        m_PurchasedButton.hidden = YES;
    }
    m_TicketImageView.hidden = !purchased;

    m_Index = index;
}

// @ 0x524a8
- (void)setArtwork:(UIImage *)artwork {
    m_ArtworkImageView.image = artwork;
}

// @ 0x52488 — swap the tile's background image.
- (void)setBgImage:(UIImage *)image {
    m_BackGroundImageView.image = image;
}

// @ 0x52530 — the button's visibility is the source of truth for the purchased flag.
- (BOOL)isPurchased {
    return !m_PurchasedButton.hidden;
}

// @ 0x52560 — show/hide the "purchased" button.
- (void)setIsPurchased:(BOOL)purchased {
    m_PurchasedButton.hidden = !purchased;
}

// @ 0x524c8 — whole-tile tap: play the decide SE, then hand off to the delegate.
- (void)handleTap:(UITapGestureRecognizer *)recognizer {
    if (![m_Delegate respondsToSelector:@selector(packViewSelected:)]) {
        return;
    }
    neSceneManager::shared();
    neEngine::playSystemSe(1);
    [m_Delegate performSelector:@selector(packViewSelected:) withObject:self];
}

// dealloc @ 0x52448 — ARC-omitted (object ivars only; the original also nils the assign
// delegate, which ARC does not require).

@end
