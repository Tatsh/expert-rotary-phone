//
//  PurchaseManager.h
//  pop'n rhythmin
//
//  StoreKit in-app-purchase manager: the payment-queue transaction observer and
//  products-request delegate. Purchased products are re-validated against the
//  Konami verify endpoint (SHA-256 digest bound to an embedded salt) before being
//  unlocked, and the owned list is persisted Blowfish-encrypted (keyed by the
//  device UUID), like the music lists.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@class PurchaseTransactionCache;

// The products-request + direct-purchase delegate (a store view controller).
@protocol PurchaseManagerDelegate <NSObject>
- (void)finishRequest:(NSArray<SKProduct *> *)products;
- (void)purchaseSucceeded:(SKPaymentTransaction *)transaction;
- (void)purchaseFailed:(id)transactionOrProductId error:(NSError *)error;
@end

// The music-download flow observes purchases/restores via a second, optional
// delegate. Note purchaseSucceeded: here receives the product identifier string
// (post receipt-verification), not the raw transaction.
@protocol PurchaseManagerMusicDelegate <NSObject>
@optional
- (void)purchaseSucceeded:(NSString *)productId;
- (void)purchaseFailed:(id)transactionOrProductId error:(NSError *)error;
- (void)restoreSucceeded;
- (void)restoreNothing;
- (void)restoreFailed:(NSError *)error;
@end

@interface PurchaseManager : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate>

+ (instancetype)sharedManager;              // Ghidra: @ 0x54450

- (void)start;                              // add self as payment observer @ 0x546c0
- (void)loadProductList;                    // decrypt "prodlist" @ 0x548d8
- (void)saveProductList;                    // encrypt + write "prodlist" @ 0x54730

// YES if `productId` is already in the (decrypted) purchased-products list.
- (BOOL)isPurchased:(NSString *)productId;  // @ 0x54aa0
// Add a product id to the owned list; optionally persist. YES if newly added.
- (BOOL)addProductID:(NSString *)productID Save:(BOOL)save;   // @ 0x54e28

// Purchase / restore entry points (all return NO if a transaction is already
// running / payments are disabled / already owned).
- (BOOL)beginPurchase:(SKProduct *)product;            // @ 0x54ac0
- (BOOL)beginConsumablePurchase:(SKProduct *)product;  // @ 0x54bbc
- (BOOL)beginRestore;                                  // @ 0x54d14

// Products validated during the current restore, before they are committed.
- (NSMutableArray *)purchaseCheckedProducts;           // @ 0x54dd8
- (void)removePurchaseCheckedProduct:(NSString *)productID;  // @ 0x54de8
- (void)clearPurchaseCheckedProducts;                  // @ 0x54e08
- (void)addProductFromPurchaseCheckedProducts;         // @ 0x54e94

// Queue a purchased/restored transaction for server receipt verification.
- (BOOL)addPurchaseCheckTransaction:(PurchaseTransactionCache *)cache;  // @ 0x54f6c

@property (nonatomic, weak) id<PurchaseManagerDelegate> delegate;
@property (nonatomic, weak) id<PurchaseManagerMusicDelegate> musicDataDelegate;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
