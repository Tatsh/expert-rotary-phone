//
//  CharaTicketData.h
//  pop'n rhythmin
//
//  Core Data managed object.
//  Reconstructed from ScoreData.momd/ScoreData_v2.mom (entity
//  "CharaTicketData").
//
//  Records character-unlock "tickets" tied to a StoreKit in-app-purchase
//  productId. One row per owned/consumed character ticket product.
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@interface CharaTicketData : NSManagedObject

@property(nonatomic, retain) NSString *productId;

// Delete every persisted CharaTicketData record (device-change / initForConvert
// reset).
+ (void)deleteAll:(NSManagedObjectContext *)context;

// Fetch every persisted CharaTicketData record (device-change conversion
// payload).
+ (id)getAllData:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
