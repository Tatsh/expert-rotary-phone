//
//  StorePackInfo.h
//  pop'n rhythmin
//
//  In-memory model of one purchasable song pack in the store: its numeric pack id,
//  display name, "new" flag, and the resolved StoreKit product. Price text is not
//  cached — it is derived on demand from the bound SKProduct via StoreUtil.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    initWithPackID:  @ 0x568ac   packID       @ 0x57370   setPackID:  @ 0x5692c
//    product          @ 0x573b0   setProduct:  @ 0x568f4   priceString @ 0x56d50
//    packName         @ 0x573a0   isNew        @ 0x57380
//  Built/cached by StorePackListController (addPackInfoFromID: @ 0x57b28,
//  getPackInfo: @ 0x57a54).
//

#import <Foundation/Foundation.h>

@class SKProduct;

@interface StorePackInfo : NSObject {
    int m_PackID;           // numeric pack identifier (server-assigned)
    SKProduct *m_Product;   // resolved StoreKit product (bound once, see setProduct:)
    NSString *m_PackName;   // display name (populated by the pack-info downloader)
    BOOL m_IsNew;           // shows the "new" marker when set
}

// Designated initializer — records the pack id; the product is bound later.
- (instancetype)initWithPackID:(int)packID;

- (int)packID;
- (void)setPackID:(int)packID;

- (SKProduct *)product;
// Set-once binder: assigns/retains only while no product is bound yet and a
// non-nil product is supplied. Returns YES if this call performed the binding.
- (BOOL)setProduct:(SKProduct *)product;

- (NSString *)packName;
- (BOOL)isNew;

// Localised price text, derived live from the bound SKProduct (StoreUtil).
- (NSString *)priceString;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
