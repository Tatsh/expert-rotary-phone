//
//  PurchaseManager.h
//  pop'n rhythmin
//
//  StoreKit in-app-purchase manager: the payment-queue transaction observer and
//  products-request delegate. The list of purchased products is persisted
//  Blowfish-encrypted (keyed by the device UUID), like the music lists.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@protocol PurchaseManagerDelegate <NSObject>
- (void)finishRequest:(NSArray<SKProduct *> *)products;
- (void)purchaseSucceeded:(SKPaymentTransaction *)transaction;
- (void)purchaseFailed:(id)transactionOrProductId error:(NSError *)error;
@end

// The music-download flow observes purchases via a second, optional delegate.
@protocol PurchaseManagerMusicDelegate <NSObject>
@optional
- (void)purchaseFailed:(id)transactionOrProductId error:(NSError *)error;
- (void)restoreFailed:(NSError *)error;
@end

@interface PurchaseManager : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate>

+ (instancetype)sharedManager;              // Ghidra: @ 0x54450

- (void)start;                              // add self as payment observer @ 0x546c0
- (void)loadProductList;                    // decrypt "prodlist" @ 0x548d8

// YES if `productId` is already in the (decrypted) purchased-products list.
- (BOOL)isPurchased:(NSString *)productId;

@property (nonatomic, weak) id<PurchaseManagerDelegate> delegate;
@property (nonatomic, weak) id<PurchaseManagerMusicDelegate> musicDataDelegate;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
