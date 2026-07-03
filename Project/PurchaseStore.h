//
//  PurchaseStore.h
//  pop'n rhythmin
//
//  Lightweight in-app-purchase observer for the jewel ("popn_jewel_1") store flow: it adopts the
//  PurchaseManager's direct-purchase delegate and just tracks whether a purchase is in flight via
//  the atomic `nowPurchasing` flag. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (purchaseSucceeded: @ 0x838d4, purchaseFailed:error: @ 0x83928, nowPurchasing @ 0x8393c,
//  setNowPurchasing: @ 0x83954).
//
//  Binary Objective-C metadata: superclass NSObject, adopts <PurchaseManagerDelegate>, a single
//  1-byte ivar. Only the two delegate callbacks and the flag accessors are present in the class'
//  method list — the protocol's -finishRequest: is not implemented by this class.
//

#import <Foundation/Foundation.h>

#import "PurchaseManager.h"   // <PurchaseManagerDelegate>

@interface PurchaseStore : NSObject <PurchaseManagerDelegate>

// YES while a purchase is being processed (set on begin, cleared on success/failure). Atomic in
// the binary (accessors emit memory barriers), so kept atomic here; the synthesized ivar is named
// `nowPurchasing` (not `_nowPurchasing`), matching the metadata.
@property (atomic, assign) BOOL nowPurchasing;   // getter @ 0x8393c / setter @ 0x83954

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
