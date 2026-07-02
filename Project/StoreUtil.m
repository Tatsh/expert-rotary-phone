//
//  StoreUtil.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreUtil.h"

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

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
