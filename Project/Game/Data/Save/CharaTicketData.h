/** @file
 * Core Data managed object. Reconstructed from ScoreData.momd/ScoreData_v2.mom (entity
 * "CharaTicketData").
 *
 * Records character-unlock "tickets" tied to a StoreKit in-app-purchase productId. There is one
 * row per owned or consumed character-ticket product.
 */

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

/**
 * @brief One owned or consumed character-ticket in-app purchase.
 */
@interface CharaTicketData : NSManagedObject

/** The StoreKit product identifier this ticket was bought as. */
@property(nonatomic, retain) NSString *productId;

/**
 * @brief Delete every persisted CharaTicketData record; the device-change and initForConvert
 * reset.
 * @param context The managed object context to delete from.
 */
+ (void)deleteAll:(NSManagedObjectContext *)context;

/**
 * @brief Fetch every persisted CharaTicketData record, for the device-change conversion payload.
 * @param context The managed object context to fetch from.
 * @return An array of CharaTicketData.
 */
+ (id)getAllData:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
