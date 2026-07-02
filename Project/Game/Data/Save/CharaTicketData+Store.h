//
//  CharaTicketData+Store.h
//  pop'n rhythmin
//
//  Fetch / insert class methods on the CharaTicketData entity (owned character
//  IAP tickets). Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "CharaTicketData.h"
#import <CoreData/CoreData.h>

@interface CharaTicketData (Store)

// YES if a ticket row exists for `productId`.  Ghidra: @ 0xe2c6c
+ (BOOL)isExistData:(NSString *)productId
    inManagedObjectContext:(NSManagedObjectContext *)context;

// Ticket row for `productId` (last match, or nil).  Ghidra: @ 0xe2c98
+ (CharaTicketData *)getDataFromProductId:(NSString *)productId
                   inManagedObjectContext:(NSManagedObjectContext *)context;

// Insert a ticket row for `productId` if one does not already exist.
// Ghidra: @ 0xe3048
+ (void)addRecordWithProductId:(NSString *)productId
        inManagedObjectContext:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
