//
//  PurchaseTransactionCache.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "PurchaseTransactionCache.h"

@implementation PurchaseTransactionCache

// @ 0x56168
- (instancetype)initWithTransaction:(SKPaymentTransaction *)transaction {
    if ((self = [super init])) {
        _productID = transaction.payment.productIdentifier;
        _receiptData = transaction.transactionReceipt; // deprecated post-iOS7, faithful to 2014
        _transactionID = transaction.transactionIdentifier;
        _transactionDate = transaction.transactionDate;
    }
    return self;
}

// dealloc @ 0x56254 — ARC-omitted (object ivars only).

@end
