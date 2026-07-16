//
//  PurchaseStore.m
//  pop'n rhythmin
//
//  See PurchaseStore.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin.
//

#import "PurchaseStore.h"

#import <StoreKit/StoreKit.h>

@implementation PurchaseStore

// ivar named `nowPurchasing` (offset +0x4), not `_nowPurchasing`, matching the
// binary. The getter/setter are the compiler-synthesized atomic accessors (they
// emit DataMemoryBarrier), so they are left to @synthesize rather than
// hand-written.
@synthesize nowPurchasing;

// @ 0x838d4 — direct-purchase success callback. The decompiled body compares
// the transaction's product identifier against "popn_jewel_1" (the jewel
// product) and clears the in-flight flag. The comparison result is not
// otherwise consumed in this method.
// @complete
- (void)purchaseSucceeded:(SKPaymentTransaction *)transaction {
    [transaction.payment.productIdentifier isEqualToString:@"popn_jewel_1"];
    nowPurchasing = NO;
}

// @ 0x83928 — direct-purchase failure callback: just clear the in-flight flag.
// @complete
- (void)purchaseFailed:(id)transactionOrProductId error:(NSError *)error {
    nowPurchasing = NO;
}

@end
