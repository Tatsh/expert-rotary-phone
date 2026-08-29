/**
 * @file
 * The lightweight in-app-purchase observer for the jewel ("popn_jewel_1") store flow.
 *
 * It adopts the PurchaseManager's direct-purchase delegate and just tracks whether a purchase is
 * in flight via the atomic `nowPurchasing` flag. Reconstructed from Ghidra project rb420, program
 * PopnRhythmin (purchaseSucceeded: @ 0x838d4, purchaseFailed:error: @ 0x83928, nowPurchasing @
 * 0x8393c, setNowPurchasing: @ 0x83954).
 *
 * The binary's Objective-C metadata gives the superclass as NSObject, adopting
 * `<PurchaseManagerDelegate>`, with a single 1-byte ivar. Only the two delegate callbacks and the
 * flag accessors are present in the class's method list; the protocol's -finishRequest: is not
 * implemented here.
 */

#import <Foundation/Foundation.h>

#import "PurchaseManager.h" // <PurchaseManagerDelegate>

/**
 * The direct-purchase delegate: it tracks whether a purchase is in flight.
 */
@interface PurchaseStore : NSObject <PurchaseManagerDelegate>

/** Whether a purchase is being processed; set on begin and cleared on success or failure. The
 * accessors are atomic, emitting memory barriers, and the synthesised ivar is named
 * `nowPurchasing` rather than `_nowPurchasing`, matching the metadata. Getter @ 0x8393c, setter @
 * 0x83954. */
@property(atomic, assign) BOOL nowPurchasing;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
