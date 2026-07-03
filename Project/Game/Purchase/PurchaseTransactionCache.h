//
//  PurchaseTransactionCache.h
//  pop'n rhythmin
//
//  Snapshot of a completed StoreKit transaction (product id + receipt + id +
//  date), kept for server-side receipt verification. Reconstructed from Ghidra
//  project rb420, program PopnRhythmin.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@interface PurchaseTransactionCache : NSObject

// Ghidra: initWithTransaction: @ 0x56168
- (instancetype)initWithTransaction:(SKPaymentTransaction *)transaction;

// Snapshot fields captured at init; read-only to callers.
// Synthesized getters (plain ivar reads):
@property (nonatomic, copy, readonly) NSString *productID;      // payment.productIdentifier // @ 0x56338
@property (nonatomic, copy, readonly) NSData *receiptData;      // transactionReceipt (legacy) // @ 0x56348
@property (nonatomic, copy, readonly) NSString *transactionID;  // transactionIdentifier // @ 0x56358
@property (nonatomic, copy, readonly) NSDate *transactionDate;  // transactionDate // @ 0x56368

// SHA-256 digest of the receipt-check request, set by PurchaseManager
// checkNextReceipt and matched against the server's echoed "code".
// Call sites: setDigestString: used @ 0x54fdc, digestString read @ 0x55a50.
// Synthesized: digestString @ 0x56378 (getter) / setDigestString: @ 0x56388 (objc_setProperty copy).
@property (nonatomic, copy) NSString *digestString;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
