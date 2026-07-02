//
//  StoreUtil.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreUtil.h"
#import "AppDelegate.h"
#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

// StoreKit product-identifier prefix (Ghidra: CFString cf_rhythmin_pack).
static NSString *const kPackProductPrefix = @"rhythmin_pack";

// Embedded digest salt — the game's internal codename. The digest slices
// characters [2, 27) out of it (Ghidra CFString @ 0x1065a3, substringWithRange:).
static NSString *const kReceiptSalt = @"Orbit Note Lumion Rhythmin Konami";

// Hex-digest helpers implemented in the binary (Ghidra ComputeMD5HexString
// @ 0x5b534 = CC_MD5, ComputeSHA256HexString @ 0x5bc04 = CC_SHA256; both return
// lowercase hex NSStrings).
extern NSString *ComputeMD5HexString(const char *cString);
extern NSString *ComputeSHA256HexString(const char *cString);

// A game-API endpoint path (Ghidra: the "%@%@%@" of "" + "/apr/main.cgi/" +
// "<name>/index.jsp").
static NSString *ApiPath(NSString *name) {
    return [NSString stringWithFormat:@"/apr/main.cgi/%@/index.jsp", name];
}

@implementation StoreUtil

+ (NSString *)targetStore {
    return @"JP";   // Ghidra: constant CFString @ 0x136e28
}

// @ 0x589f4
+ (NSURL *)createURL:(NSString *)path {
    return [[[NSURL alloc] initWithScheme:@"http" host:@"apr.konaminet.jp" path:path] autorelease];
}

// @ 0x58a58
+ (NSURL *)createHttpsURL:(NSString *)path {
    return [[[NSURL alloc] initWithScheme:@"https" host:@"apr-s.konaminet.jp" path:path] autorelease];
}

// @ 0x59f24
+ (NSURL *)createOfficialURL:(NSString *)path {
    return [[[NSURL alloc] initWithScheme:@"http" host:@"p.eagate.573.jp" path:path] autorelease];
}

// --- Game API endpoints (verified names) ---
+ (NSURL *)getDlFileListURL  { return [self createHttpsURL:ApiPath(@"get_dl_file_list")]; }   // 0x599c8
+ (NSURL *)getFriendListURL  { return [self createHttpsURL:ApiPath(@"get_friend_list")]; }    // 0x594a8
+ (NSURL *)getEventInfoURL   { return [self createHttpsURL:ApiPath(@"get_event_info")]; }     // 0x59d94
+ (NSURL *)getConvertCodeURL { return [self createHttpsURL:ApiPath(@"get_convert_code")]; }   // 0x59e00

// --- Game API endpoints (name derived from the selector; identical pattern) ---
+ (NSURL *)getFriendRequestURL { return [self createHttpsURL:ApiPath(@"get_friend_request")]; }
+ (NSURL *)getFriendScoreURL   { return [self createHttpsURL:ApiPath(@"get_friend_score")]; }
+ (NSURL *)getArcadeScoreURL   { return [self createHttpsURL:ApiPath(@"get_arcade_score")]; }
+ (NSURL *)getOverScoreLogURL  { return [self createHttpsURL:ApiPath(@"get_over_score_log")]; }
+ (NSURL *)getBlockListURL     { return [self createHttpsURL:ApiPath(@"get_block_list")]; }
+ (NSURL *)addBlockListURL     { return [self createHttpsURL:ApiPath(@"add_block_list")]; }
+ (NSURL *)delBlockListURL     { return [self createHttpsURL:ApiPath(@"del_block_list")]; }
+ (NSURL *)cancelFriendURL     { return [self createHttpsURL:ApiPath(@"cancel_friend")]; }

// @ 0x59f88 — official app-info page.
+ (NSURL *)getOfficialAppInfoURL {
    return [self createOfficialURL:@"/game/popn/rhythmin/app/appinfo.html"];
}

// --- StoreKit helpers ---

// @ 0x5a16c — currency-formatted price via NSNumberFormatter using the product's
// own priceLocale. Behavior 10.4, NSNumberFormatterCurrencyStyle.
+ (NSString *)priceString:(SKProduct *)product {
    if (product == nil) {
        return @"";
    }
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [formatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [formatter setLocale:product.priceLocale];
    NSString *result = [formatter stringFromNumber:product.price];
    [formatter release];
    return result;
}

// @ 0x5a088 — "rhythmin_pack" + zero-padded 4-digit id; nil for non-positive ids.
+ (NSString *)productIDForPackID:(int)packID {
    if (packID < 1) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@%04d", kPackProductPrefix, packID];
}

// @ 0x5a0d0 — strip the prefix and read the trailing integer; -1 on mismatch.
+ (int)packIDForProductID:(NSString *)productID {
    if (productID.length <= kPackProductPrefix.length) {
        return -1;
    }
    if (![productID hasPrefix:kPackProductPrefix]) {
        return -1;
    }
    int packID = [[productID substringFromIndex:kPackProductPrefix.length] intValue];
    return packID > 0 ? packID : -1;
}

// --- Receipt verification ---

// @ 0x58f04
+ (NSURL *)receiptURL {
    return [self createHttpsURL:ApiPath(@"verify_receipt")];
}

// @ 0x58830
+ (NSString *)deviceName {
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return @"ipad";
    }
    return @"iphone";
}

// @ 0x58880 — computed once, then cached (Ghidra DAT_001882f4).
+ (NSString *)identifierParams {
    static NSString *sIdentifierParams = nil;
    if (sIdentifierParams != nil) {
        return sIdentifierParams;
    }
    NSString *seed = [[AppDelegate appDelegate].uuId stringByAppendingString:@"STORE"];
    sIdentifierParams = [ComputeMD5HexString(seed.UTF8String) retain];
    return sIdentifierParams;
}

// @ 0x5a2ac — wrap the receipt with client info for the verify endpoint.
+ (NSString *)createReceiptCheckJSON:(NSString *)base64Receipt {
    AppDelegate *app = [AppDelegate appDelegate];
    return [NSString stringWithFormat:
            @"{\"receipt_data\":\"%@\",\"client_info\":{\"uuid\":\"%@\",\"version\":\"%@\","
            @"\"device\":\"%@\",\"os\":\"%@\",\"locale\":\"%@\"}}",
            base64Receipt,
            [self identifierParams],
            [app appVersion],
            [self deviceName],
            [app osVersion],
            [app localeString]];
}

// @ 0x5a394 — SHA-256 hex of (salt[2,27) + json).
+ (NSString *)createReceiptChecckDigest:(NSString *)json {
    NSString *salt = [kReceiptSalt substringWithRange:NSMakeRange(2, 27)];
    NSString *seed = [NSString stringWithFormat:@"%@%@", salt, json];
    return ComputeSHA256HexString(seed.UTF8String);
}

// @ 0x5a240 — must be an http(s) string that NSURL accepts.
+ (BOOL)isValidURL:(NSString *)urlString {
    if (![urlString hasPrefix:@"http://"] && ![urlString hasPrefix:@"https://"]) {
        return NO;
    }
    return [NSURL URLWithString:urlString] != nil;
}

// --- Store catalogue ---

// @ 0x58910 — the client-info query fragment shared by catalogue requests.
+ (NSString *)userInfo {
    AppDelegate *app = [AppDelegate appDelegate];
    return [NSString stringWithFormat:
            @"uuid=%@&version=%@&device=%@&os=%@&locale=%@",
            [self identifierParams],
            [app appVersion],
            [self deviceName],
            [app osVersion],
            [app localeString]];
}

// @ 0x58abc — /apr/main.cgi/packlist/index.jsp?target=JP&head=..&limit=..&<userInfo>
// with an optional &pack_id=.. seed.
+ (NSURL *)packListURL:(unsigned int)head limit:(unsigned int)limit packId:(int)packId {
    NSString *path = [NSString stringWithFormat:
                      @"%@%@?target=%@&head=%d&limit=%d&%@",
                      @"/apr/main.cgi/", @"packlist/index.jsp", [self targetStore],
                      head, limit, [self userInfo]];
    if (packId > 0) {
        path = [NSString stringWithFormat:@"%@&pack_id=%d", path, packId];
    }
    return [self createHttpsURL:path];
}

// @ 0x58b80 — /apr/main.cgi/packinfo/index.jsp?target=JP&pack=<id>[&<userInfo>]
+ (NSURL *)packInfoURL:(unsigned int)packID UserOpen:(BOOL)userOpen {
    NSString *path;
    if (userOpen) {
        path = [NSString stringWithFormat:@"%@%@?target=%@&pack=%d&%@",
                @"/apr/main.cgi/", @"packinfo/index.jsp", [self targetStore], packID,
                [self userInfo]];
    } else {
        path = [NSString stringWithFormat:@"%@%@?target=%@&pack=%d",
                @"/apr/main.cgi/", @"packinfo/index.jsp", [self targetStore], packID];
    }
    return [self createHttpsURL:path];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
