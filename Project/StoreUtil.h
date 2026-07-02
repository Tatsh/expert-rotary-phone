//
//  StoreUtil.h
//  pop'n rhythmin
//
//  Server configuration + URL builder for the app's web APIs. All endpoints are
//  built through three base URLs (the game API over http/https, and the official
//  eAmusement site) and a per-endpoint path. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin (StoreUtil @ 0x58904..0x5a060).
//

#import <Foundation/Foundation.h>

@class SKProduct;

@interface StoreUtil : NSObject

// The store/region code sent as Accept-Language. Ghidra: targetStore @ 0x58904 = "JP".
+ (NSString *)targetStore;

// Base URL builders. Ghidra: createURL: 0x589f4 (http://apr.konaminet.jp),
// createHttpsURL: 0x58a58 (https://apr-s.konaminet.jp), createOfficialURL: 0x59f24
// (http://p.eagate.573.jp).
+ (NSURL *)createURL:(NSString *)path;
+ (NSURL *)createHttpsURL:(NSString *)path;
+ (NSURL *)createOfficialURL:(NSString *)path;

// Game API endpoints (all /apr/main.cgi/<name>/index.jsp over https). Endpoint
// names are verified where noted; the rest follow the identical pattern derived
// from the selector.
+ (NSURL *)getDlFileListURL;      // 0x599c8  get_dl_file_list   (verified)
+ (NSURL *)getFriendListURL;      // 0x594a8  get_friend_list    (verified)
+ (NSURL *)getEventInfoURL;       // 0x59d94  get_event_info     (verified)
+ (NSURL *)getConvertCodeURL;     // 0x59e00  get_convert_code   (verified)
+ (NSURL *)getFriendRequestURL;   // 0x592f8  get_friend_request
+ (NSURL *)getFriendScoreURL;     // 0x59364  get_friend_score
+ (NSURL *)getArcadeScoreURL;     // 0x5995c  get_arcade_score
+ (NSURL *)getOverScoreLogURL;    // 0x59d28  get_over_score_log
+ (NSURL *)getBlockListURL;       // 0x59580  get_block_list
+ (NSURL *)addBlockListURL;       // 0x59514  add_block_list
+ (NSURL *)delBlockListURL;       // 0x595ec  del_block_list
+ (NSURL *)cancelFriendURL;       // 0x593d0  cancel_friend

// Official eAmusement pages. Ghidra: getOfficialAppInfoURL 0x59f88 (verified).
+ (NSURL *)getOfficialAppInfoURL;

// --- StoreKit helpers ---
// Localised currency string for a product's price, or @"" if product is nil.
// Ghidra: priceString: @ 0x5a16c.
+ (NSString *)priceString:(SKProduct *)product;

// StoreKit product identifier for a pack: "rhythmin_pack%04d" (nil if packID < 1).
// Ghidra: productIDForPackID: @ 0x5a088 (prefix CFString cf_rhythmin_pack).
+ (NSString *)productIDForPackID:(int)packID;

// Inverse of productIDForPackID:: parses the numeric pack id out of a product
// identifier, or -1 if it lacks the "rhythmin_pack" prefix / is non-positive.
// Ghidra: packIDForProductID: @ 0x5a0d0.
+ (int)packIDForProductID:(NSString *)productID;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
