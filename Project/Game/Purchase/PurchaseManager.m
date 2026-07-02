//
//  PurchaseManager.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "AppDelegate.h"
#import "BFCodec.h"
#import "PurchaseManager.h"
#import "PurchaseTransactionCache.h"
#import "RhUtil.h"

@implementation PurchaseManager {
    NSMutableArray *m_PurchasedProducts;
    __weak id<PurchaseManagerDelegate> m_Delegate;
    __weak id<PurchaseManagerMusicDelegate> m_MusicDataDelegate;
    BOOL m_IsMusicData;
    NSMutableArray *m_RestoredTransactions;
    BOOL m_IsRestored;
    BOOL m_Transactioing;
}

- (void)setDelegate:(id<PurchaseManagerDelegate>)delegate { m_Delegate = delegate; }
- (id<PurchaseManagerDelegate>)delegate { return m_Delegate; }
- (void)setMusicDataDelegate:(id<PurchaseManagerMusicDelegate>)d { m_MusicDataDelegate = d; }
- (id<PurchaseManagerMusicDelegate>)musicDataDelegate { return m_MusicDataDelegate; }

// @ 0x54450 — lazy singleton.
+ (instancetype)sharedManager {
    static PurchaseManager *sInstance = nil;
    if (sInstance == nil) {
        sInstance = [[PurchaseManager alloc] init];
    }
    return sInstance;
}

- (instancetype)init {
    if ((self = [super init])) {
        m_RestoredTransactions = [NSMutableArray array];
    }
    return self;
}

// @ 0x546c0 — become the StoreKit payment-queue observer.
- (void)start {
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

// @ 0x548d8 — load the Blowfish-encrypted "prodlist" (keyed by MD5(uuId)).
- (void)loadProductList {
    m_PurchasedProducts = nil;

    NSString *path = [[AppDelegate appDocumentsDirectory]
                      stringByAppendingPathComponent:@"prodlist"];
    if (RhFileExists(path)) {
        NSString *uuId = [AppDelegate appDelegate].uuId;
        NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:path];
        if (data != nil) {
            BFCodec *codec = [[BFCodec alloc] init];
            [codec cipherInit:RhMD5Data(uuId.UTF8String)];
            [codec decipher:data];
            NSData *body = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
            m_PurchasedProducts = RhParsePlistArray(body);
        }
    }
    if (m_PurchasedProducts == nil) {
        m_PurchasedProducts = [[NSMutableArray alloc] initWithCapacity:32];
    }
}

// YES if the product is already recorded as purchased.
- (BOOL)isPurchased:(NSString *)productId {
    for (id entry in m_PurchasedProducts) {
        if ([entry isKindOfClass:NSString.class]) {
            if ([entry isEqualToString:productId]) {
                return YES;
            }
        } else if ([entry isKindOfClass:NSDictionary.class]) {
            if ([entry[@"ID"] isEqual:productId] || [entry[@"productId"] isEqual:productId]) {
                return YES;
            }
        }
    }
    return NO;
}

// Queue a purchased transaction for server-side receipt verification.
// Returns YES if it was accepted for checking.
- (BOOL)addPurchaseCheckTransaction:(PurchaseTransactionCache *)cache {
    if (cache == nil) {
        return NO;
    }
    [m_RestoredTransactions addObject:cache];
    return YES;
}

#pragma mark - SKProductsRequestDelegate

// @ 0x55960
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response {
    for (NSString *invalid in response.invalidProductIdentifiers) {
        (void)invalid;  // original iterates (diagnostic) without acting
    }
    [m_Delegate finishRequest:response.products];
}

#pragma mark - SKPaymentTransactionObserver

// @ 0x551d4 — drive the purchase / fail / restore state machine.
- (void)paymentQueue:(SKPaymentQueue *)queue
    updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased: {   // 1
                if (m_Transactioing) {
                    if (!m_IsMusicData) {
                        [m_Delegate purchaseSucceeded:transaction];
                    } else {
                        PurchaseTransactionCache *cache =
                            [[PurchaseTransactionCache alloc] initWithTransaction:transaction];
                        if (![self addPurchaseCheckTransaction:cache] &&
                            [m_MusicDataDelegate respondsToSelector:@selector(purchaseFailed:error:)]) {
                            [m_MusicDataDelegate purchaseFailed:cache.productID error:nil];
                        }
                    }
                    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                    m_Transactioing = NO;
                }
                break;
            }
            case SKPaymentTransactionStateFailed: {       // 2
                if (!m_IsMusicData) {
                    [m_Delegate purchaseFailed:transaction error:transaction.error];
                } else if ([m_MusicDataDelegate respondsToSelector:@selector(purchaseFailed:error:)]) {
                    [m_MusicDataDelegate purchaseFailed:transaction error:transaction.error];
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                m_Transactioing = NO;
                break;
            }
            case SKPaymentTransactionStateRestored: {     // 3
                if (m_IsMusicData && m_Transactioing && m_IsRestored &&
                    ![self isPurchased:transaction.payment.productIdentifier]) {
                    PurchaseTransactionCache *cache =
                        [[PurchaseTransactionCache alloc] initWithTransaction:transaction];
                    [m_RestoredTransactions addObject:cache];
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            }
            default:
                break;   // Purchasing / Deferred: nothing to do
        }
    }
}

// @ 0x55798
- (void)paymentQueue:(SKPaymentQueue *)queue
    restoreCompletedTransactionsFailedWithError:(NSError *)error {
    [m_RestoredTransactions removeAllObjects];
    if ([m_MusicDataDelegate respondsToSelector:@selector(restoreFailed:)]) {
        [m_MusicDataDelegate restoreFailed:error];
    }
    m_IsRestored = NO;
    m_Transactioing = NO;
}

@end
