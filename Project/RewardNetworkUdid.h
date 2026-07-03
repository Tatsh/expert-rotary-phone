//
//  RewardNetworkUdid.h
//  pop'n rhythmin
//
//  Konami "RewardNetwork" (Applilink) ad-SDK per-device identifier helper.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (instanceSize 8:
//  isa + the single `_pasteBoard` object ivar, NSObject superclass).
//
//  NOTE: the on-device binary's RewardNetworkUdid metaclass carries a further ~28
//  class methods (the UDID generation/keychain API, e.g.
//  getUdidWithService:storageIndex:rewardNetworkUDIDType:error:); those are outside
//  the scope reconstructed here.
//

#import <Foundation/Foundation.h>

@class RewardNetworkPasteBoard;

@interface RewardNetworkUdid : NSObject

// _pasteBoard ivar / accessors @ 0xf9828 (getter) / 0xf9838 (setter).
@property (nonatomic, strong) RewardNetworkPasteBoard *pasteBoard;

// @ 0xf70c0 — runs [super init] serialized on a dedicated queue.
- (instancetype)init;

// @ 0xf956c — the app's keychain seed (Apple team) id, read from a generic-password
// item's access group.
- (NSString *)bundleSeedID;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
