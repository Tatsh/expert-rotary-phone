//
//  StorePackInfo.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StorePackInfo.h"
#import "StoreUtil.h"
#import <StoreKit/StoreKit.h>

@implementation StorePackInfo

// @ 0x568ac — record the pack id; product/name/new are filled in later.
- (instancetype)initWithPackID:(int)packID {
    if ((self = [super init])) {
        [self setPackID:packID];
    }
    return self;
}

// @ 0x57370 / 0x5692c — plain int accessors for m_PackID.
- (int)packID {
    return m_PackID;
}

- (void)setPackID:(int)packID {
    m_PackID = packID;
}

// @ 0x573b0
- (SKProduct *)product {
    return m_Product;
}

// @ 0x568f4 — bind the StoreKit product exactly once. Ignores nil, and refuses
// to overwrite an already-bound product; returns YES only when it takes.
- (BOOL)setProduct:(SKProduct *)product {
    if (m_Product == nil) {
        if (product == nil) {
            return NO;
        }
        m_Product = [product retain];
        return YES;
    }
    return NO;
}

// @ 0x573a0 / 0x57380 — display name and "new" flag (set by the downloader).
- (NSString *)packName {
    return m_PackName;
}

- (BOOL)isNew {
    return m_IsNew;
}

// @ 0x56d50 — always formatted live from the bound product.
- (NSString *)priceString {
    return [StoreUtil priceString:m_Product];
}

- (void)dealloc {
    [m_Product release];
    [m_PackName release];
    [super dealloc];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
