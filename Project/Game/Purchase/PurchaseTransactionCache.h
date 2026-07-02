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

@property (nonatomic, copy) NSString *productID;      // payment.productIdentifier
@property (nonatomic, copy) NSData *receiptData;      // transactionReceipt (legacy)
@property (nonatomic, copy) NSString *transactionID;  // transactionIdentifier
@property (nonatomic, copy) NSDate *transactionDate;  // transactionDate

// SHA-256 digest of the receipt-check request, set by PurchaseManager
// checkNextReceipt and matched against the server's echoed "code".
// Ghidra: setDigestString: (used @ 0x54fdc), digestString (read @ 0x55a50).
@property (nonatomic, copy) NSString *digestString;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
