/**
 * @file
 * @brief A snapshot of a completed StoreKit transaction: product id, receipt, id, and date.
 *
 * It is kept for server-side receipt verification. Reconstructed from Ghidra project rb420,
 * program PopnRhythmin.
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

/**
 * @brief A snapshot of a completed StoreKit transaction, kept for server-side receipt
 * verification.
 */
@interface PurchaseTransactionCache : NSObject

/**
 * @brief Snapshot a completed transaction.
 * @param transaction The transaction to snapshot.
 * @return The initialised cache entry.
 * @ghidraAddress 0x56168
 */
- (instancetype)initWithTransaction:(SKPaymentTransaction *)transaction;

// Snapshot fields captured at init; read-only to callers, with synthesised getters that are plain
// ivar reads.

/** The transaction's payment.productIdentifier. Getter @ 0x56338. */
@property(nonatomic, copy, readonly) NSString *productID;
/** The legacy transactionReceipt bytes. Getter @ 0x56348. */
@property(nonatomic, copy, readonly) NSData *receiptData;
/** The transactionIdentifier. Getter @ 0x56358. */
@property(nonatomic, copy, readonly) NSString *transactionID;
/** The transactionDate. Getter @ 0x56368. */
@property(nonatomic, copy, readonly) NSDate *transactionDate;

/**
 * The SHA-256 digest of the receipt-check request, set by -[PurchaseManager checkNextReceipt] @
 * 0x54fdc and matched against the server's echoed "code" @ 0x55a50. Getter @ 0x56378, setter @
 * 0x56388.
 */
@property(nonatomic, copy) NSString *digestString;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
