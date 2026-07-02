//
//  PurchaseManager.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "PurchaseManager.h"
#import "CommonAlertView.h"
#import <StoreKit/StoreKit.h>

// Process-wide singleton instance (Ghidra DAT_001882ec).
static PurchaseManager *s_sharedManager = nil;

// "Cannot make payments" alert copy shown by beginConsumablePurchase: — Ghidra
// CFStrings @ 0x136c88 (title) / 0x136c98 (message) / 0x1347f8 (button). These are
// Japanese; the exact glyphs were not byte-verified from the binary here.
static NSString *const kCannotPayTitle  = @"購入できません";
static NSString *const kCannotPayBody   = @"この端末では購入手続きが行えません。";
static NSString *const kCannotPayButton = @"OK";

@implementation PurchaseManager

// @ 0x54450 — lazy singleton.
+ (PurchaseManager *)sharedManager {
    if (s_sharedManager != nil) {
        return s_sharedManager;
    }
    s_sharedManager = [[PurchaseManager alloc] init];
    return s_sharedManager;
}

// @ 0x54498 — four backing arrays; flags start clear.
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

// @ 0x54aa0
- (BOOL)isPurchased:(NSString *)productIdentifier {
    return [m_PurchasedProducts containsObject:productIdentifier];
}

// @ 0x54dd8
- (NSMutableArray *)purchaseCheckedProducts {
    return m_PurchaseCheckedProducts;
}

// @ 0x54ac0 — guard, then enqueue a single-quantity payment for music data.
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

// @ 0x54bbc — consumable variant; alerts when payments are unavailable.
- (BOOL)beginConsumablePurchase:(SKProduct *)product {
    if (product == nil || m_Transactioing) {
        return NO;
    }
    if (![SKPaymentQueue canMakePayments]) {
        CommonAlertView *alert =
            [[CommonAlertView alloc] initWithTitle:kCannotPayTitle
                                           message:kCannotPayBody
                                          delegate:nil
                                 cancelButtonTitle:nil
                                 otherButtonTitles:kCannotPayButton, nil];
        [alert show];
        [alert release];
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

// @ 0x54d14 — clear the check/restore buffers and ask StoreKit to restore.
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

- (void)dealloc {
    [m_PurchasedProducts release];
    [m_PurchaseCheckedProducts release];
    [m_PurchaseCheckTransactions release];
    [m_RestoredTransactions release];
    [super dealloc];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
