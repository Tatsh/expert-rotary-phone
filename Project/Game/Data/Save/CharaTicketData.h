//
//  CharaTicketData.h
//  pop'n rhythmin
//
//  Core Data managed object.
//  Reconstructed from ScoreData.momd/ScoreData_v2.mom (entity "CharaTicketData").
//
//  Records character-unlock "tickets" tied to a StoreKit in-app-purchase
//  productId. One row per owned/consumed character ticket product.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface CharaTicketData : NSManagedObject

@property (nonatomic, retain) NSString *productId;

#pragma mark Recovered selectors
// Recovered from call sites (previously declared as local category seams).

// YES if a row for `productID` already exists in the store.
+ (BOOL)isExistData:(NSString *)productID inManagedObjectContext:(NSManagedObjectContext *)context;
// Insert a new character-ticket row for `productID`.
+ (void)addRecordWithProductId:(NSString *)productID inManagedObjectContext:(NSManagedObjectContext *)context;


// Delete every persisted CharaTicketData record (device-change / initForConvert reset).
+ (void)deleteAll:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
