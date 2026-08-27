//
//  PurchaseManager.h
//  pop'n rhythmin
//
//  StoreKit in-app-purchase manager: the payment-queue transaction observer and
//  products-request delegate. Purchased products are re-validated against the
//  Konami verify endpoint (SHA-256 digest bound to an embedded salt) before
//  being unlocked, and the owned list is persisted Blowfish-encrypted (keyed by
//  the device UUID), like the music lists. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@class PurchaseTransactionCache;

/**
 * @brief The products-request and direct-purchase delegate; in practice a store view controller.
 */
@protocol PurchaseManagerDelegate <NSObject>
// Only the products-request delegate (AppDelegate) implements this; the direct-purchase delegate
// (PurchaseStore) faithfully omits it, so it is optional. PurchaseManager only ever sends it to
// the request delegate.
@optional
/**
 * @brief An SKProductsRequest finished.
 * @param products The products the store returned.
 */
- (void)finishRequest:(NSArray<SKProduct *> *)products;
@required
/**
 * @brief A purchase completed.
 * @param transaction The completed transaction.
 */
- (void)purchaseSucceeded:(SKPaymentTransaction *)transaction;
/**
 * @brief A purchase failed.
 * @param transactionOrProductId The failed transaction, or the product identifier.
 * @param error What went wrong.
 */
- (void)purchaseFailed:(id)transactionOrProductId error:(NSError *)error;
@end

/**
 * @brief The music-download flow's view of purchases and restores, a second optional delegate.
 *
 * Its purchaseSucceeded: receives the product identifier string, post receipt-verification, rather
 * than the raw transaction.
 */
@protocol PurchaseManagerMusicDelegate <NSObject>
@optional
/**
 * @brief A purchase completed and its receipt verified.
 * @param productId The purchased product identifier.
 */
- (void)purchaseSucceeded:(NSString *)productId;
/**
 * @brief A purchase failed.
 * @param transactionOrProductId The failed transaction, or the product identifier.
 * @param error What went wrong.
 */
- (void)purchaseFailed:(id)transactionOrProductId error:(NSError *)error;
/**
 * @brief A restore completed with at least one product.
 */
- (void)restoreSucceeded;
/**
 * @brief A restore completed but found nothing to restore.
 */
- (void)restoreNothing;
/**
 * @brief A restore failed.
 * @param error What went wrong.
 */
- (void)restoreFailed:(NSError *)error;
@end

/**
 * @brief The StoreKit in-app-purchase manager: the payment-queue transaction observer and
 * products-request delegate.
 */
@interface PurchaseManager : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate>

/**
 * @brief The shared manager.
 * @return The singleton.
 * @ghidraAddress 0x54450
 */
+ (instancetype)sharedManager;

/**
 * @brief Add the manager as the payment-queue transaction observer.
 * @ghidraAddress 0x546c0
 */
- (void)start;
/**
 * @brief Remove the manager as the payment-queue transaction observer.
 * @ghidraAddress 0x546f8
 */
- (void)end;
/**
 * @brief Decrypt and load the owned-products list from "prodlist".
 * @ghidraAddress 0x548d8
 */
- (void)loadProductList;
/**
 * @brief Encrypt and write the owned-products list to "prodlist".
 * @ghidraAddress 0x54730
 */
- (void)saveProductList;

/**
 * @brief Whether @p productId is already in the decrypted purchased-products list.
 * @param productId The product identifier to test.
 * @return YES when the product is owned.
 * @ghidraAddress 0x54aa0
 */
- (BOOL)isPurchased:(NSString *)productId;
/**
 * @brief Add a product identifier to the owned list.
 * @param productID The product identifier to add.
 * @param save YES to persist the list afterwards.
 * @return YES when the product was newly added.
 * @ghidraAddress 0x54e28
 */
- (BOOL)addProductID:(NSString *)productID Save:(BOOL)save;

// Purchase and restore entry points. All return NO if a transaction is already running, payments
// are disabled, or the product is already owned.

/**
 * @brief Begin a non-consumable purchase.
 * @param product The product to buy.
 * @return YES when the payment was queued.
 * @ghidraAddress 0x54ac0
 */
- (BOOL)beginPurchase:(SKProduct *)product;
/**
 * @brief Begin a consumable purchase.
 * @param product The product to buy.
 * @return YES when the payment was queued.
 * @ghidraAddress 0x54bbc
 */
- (BOOL)beginConsumablePurchase:(SKProduct *)product;
/**
 * @brief Begin restoring previous purchases.
 * @return YES when the restore was started.
 * @ghidraAddress 0x54d14
 */
- (BOOL)beginRestore;

/**
 * @brief The products validated during the current restore, before they are committed.
 * @return The pending product identifiers.
 * @ghidraAddress 0x54dd8
 */
- (NSMutableArray *)purchaseCheckedProducts;
/**
 * @brief Drop one product from the pending-restore list.
 * @param productID The product identifier to remove.
 * @ghidraAddress 0x54de8
 */
- (void)removePurchaseCheckedProduct:(NSString *)productID;
/**
 * @brief Empty the pending-restore list.
 * @ghidraAddress 0x54e08
 */
- (void)clearPurchaseCheckedProducts;
/**
 * @brief Commit every pending-restore product into the owned list.
 * @ghidraAddress 0x54e94
 */
- (void)addProductFromPurchaseCheckedProducts;

/**
 * @brief Queue a purchased or restored transaction for server receipt verification.
 * @param cache The transaction snapshot to verify.
 * @return YES when the transaction was queued.
 * @ghidraAddress 0x54f6c
 */
- (BOOL)addPurchaseCheckTransaction:(PurchaseTransactionCache *)cache;

/**
 * @brief Start an SKProductsRequest for the given identifiers, with the manager as its delegate.
 * @param productIdentifiers The product identifiers to request.
 * @return The started request.
 * @ghidraAddress 0x55170
 */
- (SKProductsRequest *)startProductRequest:(NSSet<NSString *> *)productIdentifiers;

/** The products-request and direct-purchase delegate. */
@property(nonatomic, weak) id<PurchaseManagerDelegate> delegate;
/** The music-download flow's purchase and restore delegate. */
@property(nonatomic, weak) id<PurchaseManagerMusicDelegate> musicDataDelegate;

#pragma mark Recovered selectors

// Recovered from call sites; previously declared as local category seams.

/**
 * @brief Whether in-app purchases are currently allowed: payments enabled and not restricted.
 * @return YES when a purchase may be started.
 */
+ (BOOL)isPurchasable;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
