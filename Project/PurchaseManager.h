//
//  PurchaseManager.h
//  pop'n rhythmin
//
//  The app's StoreKit hub: a process-wide singleton that drives in-app purchases
//  and restores, tracks which product identifiers are owned, and (in the parts
//  added incrementally alongside this file) observes the payment queue to unlock
//  and download purchased music.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    sharedManager @ 0x54450   init @ 0x54498   isPurchased: @ 0x54aa0
//    purchaseCheckedProducts @ 0x54dd8   beginPurchase: @ 0x54ac0
//    beginConsumablePurchase: @ 0x54bbc   beginRestore @ 0x54d14
//
//  NOTE: the SKPaymentTransactionObserver / SKProductsRequestDelegate half of this
//  class (paymentQueue:updatedTransactions: @ 0x551d4, productsRequest:
//  didReceiveResponse: @ 0x55960, restore bookkeeping, purchased-music persistence
//  @ 0xc8xxx, sumPurchase tracking @ 0x608xx) is being reconstructed in follow-up
//  commits; those methods and the protocol conformance are declared as each lands.
//

#import <Foundation/Foundation.h>

@class SKProduct;

@interface PurchaseManager : NSObject {
    NSMutableArray *m_PurchasedProducts;         // owned product identifiers (NSString)
    NSMutableArray *m_PurchaseCheckedProducts;   // products verified this session
    NSMutableArray *m_PurchaseCheckTransactions; // transactions awaiting server check
    NSMutableArray *m_RestoredTransactions;      // transactions gathered during a restore
    BOOL m_Transactioing;                        // a StoreKit transaction is in flight
    BOOL m_IsRestored;                           // current flow is a restore, not a buy
    BOOL m_IsMusicData;                          // current purchase unlocks music data
}

+ (PurchaseManager *)sharedManager;

// YES if productIdentifier is in the owned set.
- (BOOL)isPurchased:(NSString *)productIdentifier;

- (NSMutableArray *)purchaseCheckedProducts;

// Start buying a (non-consumable) music-data product. Returns NO if a transaction
// is already running, payments are disabled, or the product is already owned.
- (BOOL)beginPurchase:(SKProduct *)product;

// Start buying a consumable product; pops a "cannot purchase" alert when the device
// cannot make payments. Returns NO if a transaction is already running.
- (BOOL)beginConsumablePurchase:(SKProduct *)product;

// Restore previously-bought products. Returns NO if a transaction is already
// running or payments are disabled.
- (BOOL)beginRestore;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
