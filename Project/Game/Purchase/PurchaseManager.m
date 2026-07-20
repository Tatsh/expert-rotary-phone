//
//  PurchaseManager.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "PurchaseManager.h"

#import "AppDelegate.h"
#import "BFCodec.h"
#import "CommonAlertView.h"
#import "Downloader.h"
#import "PurchaseTransactionCache.h"
#import "RhUtil.h"
#import "StoreUtil.h"

@interface PurchaseManager () <DownloaderDelegate>
@end

@implementation PurchaseManager {
    NSMutableArray *m_PurchasedProducts;         // owned product ids (persisted)
    NSMutableArray *m_PurchaseCheckedProducts;   // ids validated in the current restore
    NSMutableArray *m_PurchaseCheckTransactions; // transactions queued for receipt check
    NSMutableArray *m_RestoredTransactions;      // transactions gathered during a restore
    __weak id<PurchaseManagerDelegate> m_Delegate;
    __weak id<PurchaseManagerMusicDelegate> m_MusicDataDelegate;
    BOOL m_Transactioing;     // a StoreKit transaction is in flight
    BOOL m_IsRestored;        // the current flow is a restore
    BOOL m_IsMusicData;       // the current purchase unlocks music data
    Downloader *m_Downloader; // in-flight receipt-check request
}

// Plain weak accessors, synthesized onto the m_* ivars.
@synthesize delegate = m_Delegate;                   // getter @ 0x56128, setter @ 0x56138
@synthesize musicDataDelegate = m_MusicDataDelegate; // getter @ 0x56148, setter @ 0x56158

// @ 0x54450 — lazy singleton.
+ (instancetype)sharedManager {
    static PurchaseManager *sInstance = nil;
    if (sInstance == nil) {
        sInstance = [[PurchaseManager alloc] init];
    }
    return sInstance;
}

// @ 0x5459c — StoreKit availability gate: tail-call [SKPaymentQueue
// canMakePayments].
+ (BOOL)isPurchasable {
    return [SKPaymentQueue canMakePayments];
}

// @ 0x54498 — allocate the four backing arrays; flags start clear.
- (instancetype)init {
    if ((self = [super init])) {
        m_PurchasedProducts = [[NSMutableArray alloc] initWithCapacity:0];
        m_PurchaseCheckedProducts = [[NSMutableArray alloc] initWithCapacity:0];
        m_PurchaseCheckTransactions = [[NSMutableArray alloc] initWithCapacity:0];
        m_Transactioing = NO;
        m_IsRestored = NO;
        m_RestoredTransactions = [[NSMutableArray alloc] initWithCapacity:0];
    }
    return self;
}

// @ 0x546c0 — become the StoreKit payment-queue observer.
- (void)start {
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

// @ 0x546f8 — stop observing the payment queue (teardown counterpart of
// -start).
- (void)end {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

// @ 0x545b8 — cancel the in-flight receipt-check download; the four backing
// arrays are ARC-released. (Original also nils musicDataDelegate and releases
// the arrays by hand.)
- (void)dealloc {
    [self setMusicDataDelegate:nil];
    [m_Downloader cancel];
}

#pragma mark - Purchased-product persistence

// @ 0x548d8 — load the Blowfish-encrypted "prodlist" (keyed by MD5(uuId)).
- (void)loadProductList {
    m_PurchasedProducts = nil;

    NSString *path =
        [[AppDelegate appDocumentsDirectory] stringByAppendingPathComponent:@"prodlist"];
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

// @ 0x54730 — persist the owned list: plist-serialise, prepend 4 random salt
// bytes, Blowfish-encipher (keyed by MD5(uuId)), write atomically.
- (void)saveProductList {
    if (m_PurchasedProducts.count == 0) {
        return;
    }
    NSString *path =
        [[AppDelegate appDocumentsDirectory] stringByAppendingPathComponent:@"prodlist"];
    NSString *uuId = [AppDelegate appDelegate].uuId;

    NSData *xml = [NSPropertyListSerialization dataWithPropertyList:m_PurchasedProducts
                                                             format:NSPropertyListXMLFormat_v1_0
                                                            options:0
                                                              error:NULL];

    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:0x80];
    uint32_t salt = arc4random();
    [data appendBytes:&salt length:4];
    [data appendData:xml];

    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:RhMD5Data(uuId.UTF8String)];
    [codec encipher:data];
    [data writeToFile:path atomically:YES];
}

// @ 0x54e28 — record a product as owned; optionally persist. YES if newly
// added.
- (BOOL)addProductID:(NSString *)productID Save:(BOOL)save {
    if ([m_PurchasedProducts containsObject:productID]) {
        return NO;
    }
    [m_PurchasedProducts addObject:productID];
    if (save) {
        [self saveProductList];
    }
    return YES;
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

#pragma mark - Purchase-checked products (validated during a restore)

// @ 0x54dd8
- (NSMutableArray *)purchaseCheckedProducts {
    return m_PurchaseCheckedProducts;
}

// @ 0x54de8
- (void)removePurchaseCheckedProduct:(NSString *)productID {
    [m_PurchaseCheckedProducts removeObject:productID];
}

// @ 0x54e08
- (void)clearPurchaseCheckedProducts {
    [m_PurchaseCheckedProducts removeAllObjects];
}

// @ 0x54e94 — commit every validated product into the owned list, then persist.
- (void)addProductFromPurchaseCheckedProducts {
    for (NSString *productID in m_PurchaseCheckedProducts) {
        [self addProductID:productID Save:NO];
    }
    [self saveProductList];
}

#pragma mark - Purchase / restore entry points

// @ 0x54ac0 — buy a (non-consumable) music-data product.
- (BOOL)beginPurchase:(SKProduct *)product {
    if (product == nil || m_Transactioing || ![SKPaymentQueue canMakePayments]) {
        return NO;
    }
    if ([self isPurchased:product.productIdentifier]) {
        return NO;
    }
    m_Transactioing = YES;
    m_IsRestored = NO;
    m_IsMusicData = YES;
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
    payment.quantity = 1;
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    return YES;
}

// @ 0x54bbc — buy a consumable; alert if the device cannot make payments.
- (BOOL)beginConsumablePurchase:(SKProduct *)product {
    if (product == nil || m_Transactioing) {
        return NO;
    }
    if (![SKPaymentQueue canMakePayments]) {
        // "エラー" / "アプリ内課金が制限されています" / "OK"
        // (Ghidra CFStrings @ 0x136c88 / 0x136c98 / 0x1347f8).
        CommonAlertView *alert =
            [[CommonAlertView alloc] initWithTitle:@"エラー"
                                           message:@"アプリ内課金が制限されています"
                                          delegate:nil
                                 cancelButtonTitle:nil
                                 otherButtonTitles:@"OK"];
        [alert show];
        return NO;
    }
    m_Transactioing = YES;
    m_IsRestored = NO;
    m_IsMusicData = NO;
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
    payment.quantity = 1;
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    return YES;
}

// @ 0x54d14 — restore previous purchases.
- (BOOL)beginRestore {
    if (m_Transactioing || ![SKPaymentQueue canMakePayments]) {
        return NO;
    }
    [m_PurchaseCheckedProducts removeAllObjects];
    [m_RestoredTransactions removeAllObjects];
    m_Transactioing = YES;
    m_IsRestored = YES;
    m_IsMusicData = YES;
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    return YES;
}

#pragma mark - Receipt verification

// @ 0x54f6c — queue a purchased transaction for server receipt check (unless it
// is already owned). Kicks the check pump. YES if accepted.
- (BOOL)addPurchaseCheckTransaction:(PurchaseTransactionCache *)cache {
    if (cache == nil) {
        return NO;
    }
    if ([self isPurchased:cache.productID]) {
        return NO;
    }
    [m_PurchaseCheckTransactions addObject:cache];
    [self checkNextReceipt];
    return YES;
}

// @ 0x54fdc — if idle, POST the next queued receipt (base64 + digest) to the
// verify endpoint. YES if a request was started.
- (BOOL)checkNextReceipt {
    if (m_PurchaseCheckTransactions.count == 0 || m_Downloader != nil) {
        return NO;
    }
    PurchaseTransactionCache *cache = [m_PurchaseCheckTransactions lastObject];

    NSString *base64 = [self encodedStringWithBase64:cache.receiptData];
    NSString *json = [StoreUtil createReceiptCheckJSON:base64];
    cache.digestString = [StoreUtil createReceiptChecckDigest:json];

    m_Downloader = [[Downloader alloc] initWithURL:[StoreUtil receiptURL]
                                          delegate:self
                                              Post:[json dataUsingEncoding:NSUTF8StringEncoding]
                                       ContextType:@"application/json"];
    m_Downloader.addData = cache;
    [m_PurchaseCheckTransactions removeObject:cache];
    [m_Downloader startDownloading];
    return YES;
}

// @ 0x55824 — base64-encode with '=' padding (the binary hand-rolls this).
- (NSString *)encodedStringWithBase64:(NSData *)data {
    static const char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const unsigned char *bytes = data.bytes;
    NSUInteger length = data.length;
    NSMutableString *out = [NSMutableString stringWithCapacity:((length + 2) / 3) * 4];
    for (NSUInteger i = 0; i < length; i += 3) {
        NSUInteger remaining = length - i;
        unsigned char b0 = bytes[i];
        unsigned char b1 = (remaining > 1) ? bytes[i + 1] : 0;
        unsigned char b2 = (remaining > 2) ? bytes[i + 2] : 0;
        char c0 = table[b0 >> 2];
        char c1 = table[((b0 & 0x03) << 4) | (b1 >> 4)];
        char c2 = (remaining > 1) ? table[((b1 & 0x0f) << 2) | (b2 >> 6)] : '=';
        char c3 = (remaining > 2) ? table[b2 & 0x3f] : '=';
        [out appendFormat:@"%c%c%c%c", c0, c1, c2, c3];
    }
    return out;
}

#pragma mark - SKProductsRequestDelegate

// @ 0x55170 — query the store for a set of product identifiers (self is the
// delegate); the response arrives in -productsRequest:didReceiveResponse:.
- (SKProductsRequest *)startProductRequest:(NSSet<NSString *> *)productIdentifiers {
    SKProductsRequest *request =
        [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    request.delegate = self;
    [request start];
    return request;
}

// @ 0x55960 — the binary walks invalidProductIdentifiers without acting on
// them, then forwards the valid products to the delegate.
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response {
    [m_Delegate finishRequest:response.products];
}

#pragma mark - SKPaymentTransactionObserver

// @ 0x551d4 — drive the purchase / fail / restore state machine.
- (void)paymentQueue:(SKPaymentQueue *)queue
    updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
        case SKPaymentTransactionStatePurchased: { // 1
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
            }
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            m_Transactioing = NO;
            break;
        }
        case SKPaymentTransactionStateFailed: { // 2
            if (!m_IsMusicData) {
                [m_Delegate purchaseFailed:transaction error:transaction.error];
            } else if ([m_MusicDataDelegate respondsToSelector:@selector(purchaseFailed:error:)]) {
                [m_MusicDataDelegate purchaseFailed:transaction error:transaction.error];
            }
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            m_Transactioing = NO;
            break;
        }
        case SKPaymentTransactionStateRestored: { // 3
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
            break; // Purchasing / Deferred: nothing to do
        }
    }
}

// @ 0x55554 — the original walks the removed transactions but takes no action.
- (void)paymentQueue:(SKPaymentQueue *)queue
    removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
}

// @ 0x555f4 — all restored transactions collected: pump receipt checks, or
// report "nothing to restore" when the queue is empty. (The binary also runs an
// empty fast-enumeration over m_RestoredTransactions before the pump loop; it
// has no observable effect and is omitted here.)
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    while (YES) {
        if (m_RestoredTransactions.count == 0) {
            if ([m_MusicDataDelegate respondsToSelector:@selector(restoreNothing)]) {
                [m_MusicDataDelegate restoreNothing];
            }
            m_IsRestored = NO;
            m_Transactioing = NO;
            break;
        }
        PurchaseTransactionCache *cache = [m_RestoredTransactions lastObject];
        [m_RestoredTransactions removeLastObject];
        if ([self addPurchaseCheckTransaction:cache]) {
            break; // a receipt check is now running; the rest continue on completion
        }
    }
}

// @ 0x55798
- (void)paymentQueue:(SKPaymentQueue *)queue
    restoreCompletedTransactionsFailedWithError:(NSError *)error {
    // Binary clears ONLY m_RestoredTransactions here (single -removeAllObjects
    // @0x55798); m_PurchaseCheckedProducts is left intact.
    [m_RestoredTransactions removeAllObjects];
    if ([m_MusicDataDelegate respondsToSelector:@selector(restoreFailed:)]) {
        [m_MusicDataDelegate restoreFailed:error];
    }
    m_IsRestored = NO;
    m_Transactioing = NO;
}

#pragma mark - DownloaderDelegate (receipt-check response)

// @ 0x55a50 — the verify server answered: accept the unlock only when
// status==0 and the echoed "code" matches the digest we sent.
- (void)downloaderFinished:(Downloader *)downloader {
    PurchaseTransactionCache *cache = downloader.addData;
    NSString *productID = cache.productID;
    NSDictionary *json = [downloader getDataInJSON];

    BOOL valid = NO;
    if (json != nil && [json[@"status"] intValue] == 0) {
        valid = [json[@"code"] isEqualToString:cache.digestString];
    }

    if (!m_IsRestored) {
        if (valid) {
            if ([m_MusicDataDelegate respondsToSelector:@selector(purchaseSucceeded:)]) {
                [m_MusicDataDelegate purchaseSucceeded:productID];
            }
        } else {
            NSError *error = [self receiptError];
            if ([m_MusicDataDelegate respondsToSelector:@selector(purchaseFailed:error:)]) {
                [m_MusicDataDelegate purchaseFailed:productID error:error];
            }
        }
        m_Transactioing = NO;
    } else if (valid) {
        [m_PurchaseCheckedProducts addObject:productID];
    } else {
        [m_PurchaseCheckedProducts removeAllObjects];
        [m_RestoredTransactions removeAllObjects];
        if ([m_MusicDataDelegate respondsToSelector:@selector(restoreFailed:)]) {
            [m_MusicDataDelegate restoreFailed:[self receiptError]];
        }
        m_Transactioing = NO;
        m_IsRestored = NO;
    }

    m_Downloader = nil;

    // During a restore, keep pumping the remaining restored transactions.
    if (m_IsRestored) {
        while (YES) {
            if (m_RestoredTransactions.count == 0) {
                if ([m_MusicDataDelegate respondsToSelector:@selector(restoreSucceeded)]) {
                    [m_MusicDataDelegate restoreSucceeded];
                }
                m_Transactioing = NO;
                m_IsRestored = NO;
                return;
            }
            PurchaseTransactionCache *next = [m_RestoredTransactions lastObject];
            [m_RestoredTransactions removeLastObject];
            if ([self addPurchaseCheckTransaction:next]) {
                break;
            }
        }
    }
}

// @ 0x55ebc — the verify request failed at the network layer.
- (void)downloaderError:(Downloader *)downloader {
    PurchaseTransactionCache *cache = downloader.addData;
    NSString *productID = cache.productID;

    if (!m_IsRestored) {
        NSError *error = [self receiptError];
        if ([m_MusicDataDelegate respondsToSelector:@selector(purchaseFailed:error:)]) {
            [m_MusicDataDelegate purchaseFailed:productID error:error];
        }
    } else {
        [m_PurchaseCheckedProducts removeAllObjects];
        [m_RestoredTransactions removeAllObjects];
        if ([m_MusicDataDelegate respondsToSelector:@selector(restoreFailed:)]) {
            [m_MusicDataDelegate restoreFailed:[self receiptError]];
        }
    }

    m_Downloader = nil;
    m_Transactioing = NO;
    m_IsRestored = NO;
}

// @ 0x55eb8 — DownloaderDelegate progress hook (no-op in this manager).
- (void)downloaderProceed:(Downloader *)downloader {
}

// The empty-domain, empty-description NSError the original builds on receipt
// failure (Ghidra: errorWithDomain:@"" code:0
// userInfo:{NSLocalizedDescription:@""}).
- (NSError *)receiptError {
    return [NSError errorWithDomain:@"" code:0 userInfo:@{NSLocalizedDescriptionKey : @""}];
}

@end
