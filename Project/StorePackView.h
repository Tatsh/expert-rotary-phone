//
//  StorePackView.h
//  pop'n rhythmin
//
//  A single tappable song-pack tile shown in the store list: a framed jacket with
//  a drop shadow, name / one-line comment / price labels, a disabled "purchased"
//  button, and new / arcade-viewer / chara-ticket marker icons. A whole-tile tap
//  gesture plays a decide SE and notifies the delegate.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    initWithFrame:      @ 0x51a44   loadPackInfo:index: @ 0x5258c
//    isPurchased         @ 0x52530   handleTap:          @ 0x524c8
//    setArtwork:         @ 0x524a8
//

#import <UIKit/UIKit.h>

@class StorePackInfo;
@class StorePackView;

// Implemented by the hosting controller (StoreMainViewController packViewSelected:
// @ 0x45318). Invoked via -respondsToSelector:/-performSelector:withObject:.
@protocol StorePackViewDelegate <NSObject>
@optional
- (void)packViewSelected:(StorePackView *)packView;
@end

@interface StorePackView : UIView {
    UIImageView *m_BackGroundImageView;    // full-bounds, carries the tap gesture
    UIImageView *m_ArtworkImageView;       // jacket (15,15,110,110), framed + shadowed
    UILabel *m_NameLabel;                  // pack name
    UILabel *m_CommentLabel;               // one-line blurb (StorePackInfo.s_comment)
    UILabel *m_PriceLabel;                 // localised price
    UIButton *m_PurchasedButton;           // disabled "purchased" pill
    UIImageView *m_NewMarker;              // "store_new" badge
    UIImageView *m_ArcadeViewerImageView;  // "store_arcade_view_ic" badge
    UIImageView *m_TicketImageView;        // "store_chara_ic" badge
    unsigned int m_Index;                  // row index passed back on selection
    id<StorePackViewDelegate> m_Delegate;  // weak (assign) — the list controller
}

@property (nonatomic, assign) id<StorePackViewDelegate> delegate;
@property (nonatomic, readonly) unsigned int index;

// Bind a pack model to the tile and record its list index.
- (void)loadPackInfo:(StorePackInfo *)packInfo index:(unsigned int)index;

// Replace the jacket artwork image.
- (void)setArtwork:(UIImage *)artwork;

// YES while the "purchased" button is visible (derived from its hidden flag).
- (BOOL)isPurchased;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
