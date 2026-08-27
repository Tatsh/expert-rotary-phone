/** @file
 * Fetch and insert class methods on the CharaTicketData entity (owned character in-app-purchase
 * tickets). Reconstructed from Ghidra project rb420, program PopnRhythmin.
 */

#import <CoreData/CoreData.h>

#import "CharaTicketData.h"

/**
 * @brief Fetch and insert helpers for the CharaTicketData entity.
 */
@interface CharaTicketData (Store)

/**
 * @brief Whether a ticket row exists for @p productId.
 * @param productId The StoreKit product identifier.
 * @param context The managed object context to fetch from.
 * @return YES when a row exists.
 * @ghidraAddress 0xe2c6c
 */
+ (BOOL)isExistData:(NSString *)productId inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief The ticket row for @p productId.
 * @param productId The StoreKit product identifier.
 * @param context The managed object context to fetch from.
 * @return The last matching record, or nil when there is none.
 * @ghidraAddress 0xe2c98
 */
+ (CharaTicketData *)getDataFromProductId:(NSString *)productId
                   inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Insert a ticket row for @p productId if one does not already exist.
 * @param productId The StoreKit product identifier.
 * @param context The managed object context to insert into.
 * @ghidraAddress 0xe3048
 */
+ (void)addRecordWithProductId:(NSString *)productId
        inManagedObjectContext:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
