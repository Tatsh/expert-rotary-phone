//
//  StoreUtil.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreUtil.h"
#import "AppDelegate.h"
#import "RhUtil.h"
#import "UserSettingData.h"
#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

// StoreKit product-identifier prefix (Ghidra: CFString cf_rhythmin_pack).
static NSString *const kPackProductPrefix = @"rhythmin_pack";

// Embedded digest salt — the game's internal codename. The digest slices
// characters [2, 27) out of it (Ghidra CFString @ 0x1065a3, substringWithRange:).
static NSString *const kReceiptSalt = @"Orbit Note Lumion Rhythmin Konami";

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
    return [[NSURL alloc] initWithScheme:@"http" host:@"apr.konaminet.jp" path:path];
}

// @ 0x58a58
+ (NSURL *)createHttpsURL:(NSString *)path {
    return [[NSURL alloc] initWithScheme:@"https" host:@"apr-s.konaminet.jp" path:path];
}

// @ 0x59f24
+ (NSURL *)createOfficialURL:(NSString *)path {
    return [[NSURL alloc] initWithScheme:@"http" host:@"p.eagate.573.jp" path:path];
}

// --- Game API endpoints (verified names) ---
+ (NSURL *)getDlFileListURL  { return [self createHttpsURL:ApiPath(@"get_dl_file_list")]; }   // 0x599c8
+ (NSURL *)getFriendListURL  { return [self createHttpsURL:ApiPath(@"get_friend_list")]; }    // 0x594a8
+ (NSURL *)getEventInfoURL   { return [self createHttpsURL:ApiPath(@"get_event_info")]; }     // 0x59d94
+ (NSURL *)getConvertCodeURL { return [self createHttpsURL:ApiPath(@"get_convert_code")]; }   // 0x59e00

// --- Friend actions (verified endpoint names) ---
+ (NSURL *)requestFriendURL      { return [self createHttpsURL:ApiPath(@"request_friend")]; }       // 0x59220
+ (NSURL *)replyFriendURL        { return [self createHttpsURL:ApiPath(@"reply_friend")]; }         // 0x5928c
+ (NSURL *)removeFriendURL       { return [self createHttpsURL:ApiPath(@"remove_friend")]; }        // 0x5943c
+ (NSURL *)getRecommendFriendURL { return [self createHttpsURL:ApiPath(@"get_recommend_friend")]; } // 0x59a34
+ (NSURL *)saveTreasureURL       { return [self createHttpsURL:ApiPath(@"save_treasure")]; }        // 0x59884

// @ 0x59740 — the recommended-pack endpoint. Note this one does NOT use ApiPath: its path
// is a byte-verified literal "/apr/main/cgi/" (slashes, not the "main.cgi" dot form) plus
// "pack_recommend/index.jsp".
+ (NSURL *)recommendPackURL {
    return [self createHttpsURL:[NSString stringWithFormat:@"%@%@",
                                 @"/apr/main/cgi/", @"pack_recommend/index.jsp"]];
}

// @ 0x59148 — the invite-code redemption endpoint. Same literal-path form as
// recommendPackURL (byte-verified "/apr/main/cgi/" slashes) plus "invited/index.jsp".
+ (NSURL *)invitedURL {
    return [self createHttpsURL:[NSString stringWithFormat:@"%@%@",
                                 @"/apr/main/cgi/", @"invited/index.jsp"]];
}

// --- Game API endpoints (name derived from the selector; identical pattern) ---
+ (NSURL *)getFriendRequestURL { return [self createHttpsURL:ApiPath(@"get_friend_request")]; }
+ (NSURL *)getFriendScoreURL   { return [self createHttpsURL:ApiPath(@"get_friend_score")]; }
+ (NSURL *)getArcadeScoreURL   { return [self createHttpsURL:ApiPath(@"get_arcade_score")]; }
+ (NSURL *)getOverScoreLogURL  { return [self createHttpsURL:ApiPath(@"get_over_score_log")]; }
+ (NSURL *)getBlockListURL     { return [self createHttpsURL:ApiPath(@"get_block_list")]; }
+ (NSURL *)addBlockListURL     { return [self createHttpsURL:ApiPath(@"add_block_list")]; }
+ (NSURL *)delBlockListURL     { return [self createHttpsURL:ApiPath(@"del_block_list")]; }
+ (NSURL *)cancelFriendURL     { return [self createHttpsURL:ApiPath(@"cancel_friend")]; }

// @ 0x59658 / 0x596cc — daily-quiz endpoints. Path is a literal "/apr/main.cgi/" +
// "<name>/index.jsp" plus a "?target=JP" query (Ghidra fmt "%@%@?target=%@", store "JP").
+ (NSURL *)getQuizURL {
    return [self createHttpsURL:[NSString stringWithFormat:@"%@%@?target=%@",
                                 @"/apr/main.cgi/", @"get_quiz/index.jsp", @"JP"]];
}
+ (NSURL *)replyQuizURL {
    return [self createHttpsURL:[NSString stringWithFormat:@"%@%@?target=%@",
                                 @"/apr/main.cgi/", @"reply_quiz/index.jsp", @"JP"]];
}

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
    return result;
}

// @ 0x5a088 — "rhythmin_pack" + zero-padded 4-digit id; nil for non-positive ids.
+ (NSString *)productIDForPackID:(int)packID {
    if (packID < 1) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@%04d", kPackProductPrefix, packID];
}

// @ 0x5a400 — Japan youth-spending-limit check: can a purchase of `price` yen proceed?
// Age is derived from the saved birthday (defaulting to 14 when none is set); 18+ has no
// limit. Under-16 is capped at 5000 yen/month, 16-17 at 10000 yen/month, counting the
// running monthly total (reset implicitly when the stored month no longer matches now).
+ (BOOL)isPurchasable:(unsigned int)price {
    NSDate *birthDay = [UserSettingData birthDay];
    NSCalendar *cal = [[NSCalendar alloc]
        initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *now = [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth)
                                   fromDate:[NSDate date]];

    NSInteger age;
    if (birthDay == nil) {
        age = 14;   // no recorded birthday -> treated as a minor
    } else {
        // Age as of the 1st of this month at noon (parsed back through a formatter so the
        // day/time are pinned, matching the binary).
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-ddHH:mm:ss";
        NSString *cutoffStr = [NSString stringWithFormat:@"%04ld-%02ld-0112:00:00",
                               (long)now.year, (long)now.month];
        NSDate *cutoff = [fmt dateFromString:cutoffStr];
        NSDateComponents *span =
            [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay)
                   fromDate:birthDay toDate:cutoff options:0];
        age = span.year;
        if (age > 17) {
            return YES;   // adult: no spending limit
        }
    }

    int spent = 0;
    NSDate *lastUpdate = [UserSettingData lastUpdateSumPurchase];
    if (lastUpdate != nil) {
        NSDateComponents *last = [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth)
                                        fromDate:lastUpdate];
        if (last.year == now.year && last.month == now.month) {
            spent = [UserSettingData sumPurchase];   // same month: include the running total
        }
    }

    unsigned int limit = (age < 16) ? 5001 : 10001;   // 0x1389 / 0x2711
    return (price + spent) < limit;
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
    sIdentifierParams = ComputeMD5HexString(seed.UTF8String);
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

// @ 0x58c5c — store per-song info page:
// /apr/main.cgi/musicinfo/index.jsp?target=JP&music=<id>&<userInfo>
+ (NSURL *)musicInfoURL:(unsigned int)musicId {
    NSString *path = [NSString stringWithFormat:
                      @"%@%@?target=%@&music=%d&%@",
                      @"/apr/main.cgi/", @"musicinfo/index.jsp", [self targetStore],
                      musicId, [self userInfo]];
    return [self createHttpsURL:path];
}

// @ 0x58cf4 — arcade-viewer per-song info page:
// /apr/main.cgi/acv_musicinfo/index.jsp?target=JP&music=<id>&<userInfo>
+ (NSURL *)acvMusicInfoURL:(unsigned int)acMusicId {
    NSString *path = [NSString stringWithFormat:
                      @"%@%@?target=%@&music=%d&%@",
                      @"/apr/main.cgi/", @"acv_musicinfo/index.jsp", [self targetStore],
                      acMusicId, [self userInfo]];
    return [self createHttpsURL:path];
}

// @ 0x59b0c — arcade-viewer play-log POST endpoint:
// https://apr-s.konaminet.jp/apr/main.cgi/log_acv_play/index.jsp
+ (NSURL *)logAcvPlayURL {
    return [self createHttpsURL:[NSString stringWithFormat:@"%@%@",
                                 @"/apr/main.cgi/", @"log_acv_play/index.jsp"]];
}

// @ 0x59ed8 — the official eAmusement site base string:
// "http://p.eagate.573.jp/game/popn/rhythmin/".
+ (NSString *)getOfficialPath {
    return [NSString stringWithFormat:@"http://%@%@",
            @"p.eagate.573.jp", @"/game/popn/rhythmin/"];
}

// @ 0x5a060 — official pop'n team Twitter page.
+ (NSURL *)getOfficialTwitterURL {
    return [NSURL URLWithString:@"https://twitter.com/popn_team"];
}

@end

// @ 0x5c5ec — percent-encode a string for use in a URL query. Escapes the reserved
// set "!*'();:@&=+$,/?%#[]" using UTF-8 (kCFStringEncodingUTF8). nil in -> nil out.
NSString *urlEncodeString(NSString *s) {
    if (s == nil) {
        return nil;
    }
    return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(
        kCFAllocatorDefault, (__bridge CFStringRef)s, NULL,
        CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8);
}
