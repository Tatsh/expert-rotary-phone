//
//  StorePackDetailViewPad.h
//  pop'n rhythmin
//
//  The iPad in-place pack-detail panel: an embedded view (shown over a dimmed
//  cover) that displays a StorePackInfo — jacket, name, price, song list, and the
//  purchase button — without pushing a new screen. Bound via setPackInfo:.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (setPackInfo: @ 0x50b58).
//

#import <UIKit/UIKit.h>

@class StorePackInfo;
@class StorePackDetailViewPad;

@protocol StorePackDetailViewPadDelegate <NSObject>
@optional
- (void)packDetailViewPad:(StorePackDetailViewPad *)view didSelectPurchase:(StorePackInfo *)packInfo;
- (void)packDetailViewPadDidClose:(StorePackDetailViewPad *)view;
@end

@interface StorePackDetailViewPad : UIView {
    StorePackInfo *m_PackInfo;
    __weak id<StorePackDetailViewPadDelegate> m_Delegate;
}

@property (nonatomic, retain) StorePackInfo *packInfo;   // @ 0x50b58 (setter)
@property (nonatomic, weak) id<StorePackDetailViewPadDelegate> delegate;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
