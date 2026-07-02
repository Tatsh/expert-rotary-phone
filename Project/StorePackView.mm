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

@synthesize delegate = m_Delegate;
@synthesize index = m_Index;

// @ 0x51a44 — build the tile. Colours/offsets are the exact IEEE-754 constants
// from the decompiled initialiser; a few label frames are approximate because the
// original arithmetic was emitted as NEON vector ops the decompiler could not fully
// recover (noted inline).
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        // Background image view fills the tile and owns the tap gesture.
        m_BackGroundImageView = [[[UIImageView alloc] initWithFrame:self.bounds] autorelease];
        m_BackGroundImageView.userInteractionEnabled = YES;
        m_BackGroundImageView.exclusiveTouch = YES;
        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [m_BackGroundImageView addGestureRecognizer:tap];
        [tap release];
        [m_BackGroundImageView retain];   // held as an ivar (also added as subview below)

        // Jacket artwork: (15,15,110,110), aspect-fit, faint white fill, 1pt white
        // border, soft black drop shadow, rasterized.
        m_ArtworkImageView =
            [[[UIImageView alloc] initWithFrame:CGRectMake(15, 15, 110, 110)] autorelease];
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
        [m_ArtworkImageView retain];

        // Name label — right of the jacket. Original x = frameWidth + (-145.0)
        // (DAT_0005204c). Width 140, height ~20, auto-shrinking font @ 17pt white.
        m_NameLabel = [[[UILabel alloc]
            initWithFrame:CGRectMake(CGRectGetWidth(frame) - 145.0f, 14, 140, 20)] autorelease];
        m_NameLabel.backgroundColor = [UIColor clearColor];
        m_NameLabel.font = [UIFont fontWithName:AppFontName() size:17.0f];
        m_NameLabel.textColor = [UIColor colorWithWhite:0.0f alpha:1.0f];
        m_NameLabel.adjustsFontSizeToFitWidth = YES;
        m_NameLabel.minimumScaleFactor = 0.6f;
        [m_NameLabel retain];

        // "Purchased" pill — a custom button that is always disabled; it only shows
        // a disabled-state background ("store_btn_disabled.png", 6pt stretchable caps)
        // and a Japanese "purchased" title (Ghidra cf_eQn_0; glyphs not byte-verified).
        m_PurchasedButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
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
        [m_PurchasedButton setTitle:@"購入済み"    // cf_eQn_0 (Japanese "purchased")
                           forState:UIControlStateDisabled];
        m_PurchasedButton.enabled = NO;
        [m_PurchasedButton sizeToFit];
        // Positioned relative to the tile's bottom-right in the original (vector math).

        // Comment label — one-line blurb under the name. (The initialiser adds it as a
        // subview; its construction was folded by the decompiler, so its frame mirrors
        // the name label's column.)
        m_CommentLabel = [[[UILabel alloc]
            initWithFrame:CGRectMake(CGRectGetWidth(frame) - 145.0f, 40, 140, 18)] autorelease];
        m_CommentLabel.backgroundColor = [UIColor clearColor];
        m_CommentLabel.font = [UIFont fontWithName:AppFontName() size:13.0f];
        m_CommentLabel.textColor = [UIColor colorWithWhite:0.0f alpha:1.0f];
        [m_CommentLabel retain];

        // Price label — width 140, height 32, dim (white 0.196) @ 15pt.
        m_PriceLabel = [[[UILabel alloc]
            initWithFrame:CGRectMake(CGRectGetWidth(frame) - 145.0f, 100, 140, 32)] autorelease];
        m_PriceLabel.backgroundColor = [UIColor clearColor];
        m_PriceLabel.font = [UIFont fontWithName:AppFontName() size:15.0f];
        m_PriceLabel.textColor = [UIColor colorWithWhite:0.196f alpha:1.0f];
        [m_PriceLabel retain];

        // "New" badge.
        m_NewMarker = [[[UIImageView alloc]
            initWithImage:[UIImage imageNamed:@"store_new.png"]] autorelease];
        [m_NewMarker retain];

        // Arcade-viewer badge at (140,77), hidden until a pack has arcade content.
        UIImage *acvImg = [UIImage imageNamed:@"store_arcade_view_ic"];
        m_ArcadeViewerImageView = [[[UIImageView alloc] initWithImage:acvImg] autorelease];
        m_ArcadeViewerImageView.frame =
            CGRectMake(140.0f, 77.0f, acvImg.size.width, acvImg.size.height);
        m_ArcadeViewerImageView.hidden = YES;
        [m_ArcadeViewerImageView retain];

        // Chara-ticket badge at (140, below the arcade badge).
        UIImage *charaImg = [UIImage imageNamed:@"store_chara_ic"];
        CGFloat ticketY = CGRectGetMaxY(m_ArcadeViewerImageView.frame);
        m_TicketImageView = [[[UIImageView alloc] initWithImage:charaImg] autorelease];
        m_TicketImageView.frame =
            CGRectMake(140.0f, ticketY, charaImg.size.width, charaImg.size.height);
        [m_TicketImageView retain];

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

// @ 0x52530 — the button's visibility is the source of truth for the purchased flag.
- (BOOL)isPurchased {
    return !m_PurchasedButton.hidden;
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

- (void)dealloc {
    [m_BackGroundImageView release];
    [m_ArtworkImageView release];
    [m_NameLabel release];
    [m_CommentLabel release];
    [m_PriceLabel release];
    [m_PurchasedButton release];
    [m_NewMarker release];
    [m_ArcadeViewerImageView release];
    [m_TicketImageView release];
    [super dealloc];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
