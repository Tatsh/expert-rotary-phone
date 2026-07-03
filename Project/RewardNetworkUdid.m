//
//  RewardNetworkUdid.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RewardNetworkUdid.h"
#import "RewardNetworkPasteBoard.h"

#import <Security/Security.h>

@implementation RewardNetworkUdid

// @ 0xf70c0 — the recovered -init dispatches its super initialization synchronously
// onto a process-wide serial queue (block body @ 0xf7188 does just `self = [super
// init]`). The queue serializes the SDK's UDID/keychain work; it is reproduced here
// as a lazily-created serial queue.
- (instancetype)init {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("jp.applilink.reward.udid", DISPATCH_QUEUE_SERIAL);
    });

    __block RewardNetworkUdid *result = nil;
    dispatch_sync(queue, ^{
        result = [super init];
    });
    return result;
}

// setPasteBoard: @ 0xf9838 / pasteBoard @ 0xf9828 — synthesized accessors for the
//   _pasteBoard ivar.
// .cxx_construct/.cxx_destruct @ 0xf9860 — compiler-emitted ARC ivar teardown for
//   _pasteBoard; not hand-written.

// @ 0xf956c — look up (creating if absent) a generic-password keychain item named
// "bundleSeedID" and read the leading component of its access group, which is the
// app's Apple seed (team) id.
- (NSString *)bundleSeedID {
    NSDictionary *query = @{
        (__bridge id)kSecClass:            (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount:      @"bundleSeedID",
        (__bridge id)kSecAttrService:      @"",
        (__bridge id)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
    };

    CFTypeRef resultRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &resultRef);
    if (status == errSecItemNotFound) {
        status = SecItemAdd((__bridge CFDictionaryRef)query, &resultRef);
    }
    if (status != errSecSuccess) {
        if (resultRef != NULL) {
            CFRelease(resultRef);
        }
        return nil;
    }

    NSDictionary *attributes = (__bridge_transfer NSDictionary *)resultRef;
    NSString *accessGroup = [attributes objectForKey:(__bridge id)kSecAttrAccessGroup];
    return [[[accessGroup componentsSeparatedByString:@"."] objectEnumerator] nextObject];
}

@end
