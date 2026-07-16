//
//  PurchaseTransactionCache.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "PurchaseTransactionCache.h"

@implementation PurchaseTransactionCache

// @ 0x56168
// @complete
- (instancetype)initWithTransaction:(SKPaymentTransaction *)transaction {
    if ((self = [super init])) {
        _productID = transaction.payment.productIdentifier;
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
        // The per-transaction receipt was removed in favour of a single
        // app-store receipt covering the whole bundle, so this is not a strict
        // per-transaction equivalent but is the sanctioned modern source.
        _receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
#else
        _receiptData = transaction.transactionReceipt; // deprecated post-iOS7, faithful to 2014
#endif
        _transactionID = transaction.transactionIdentifier;
        _transactionDate = transaction.transactionDate;
    }
    return self;
}

// dealloc @ 0x56254 — ARC-omitted (object ivars only).

@end
