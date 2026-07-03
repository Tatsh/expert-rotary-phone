//
//  OverScoreData.m
//  pop'n rhythmin
//

#import "OverScoreData.h"

@implementation OverScoreData

@dynamic music;
@dynamic sheet;
@dynamic isTouched;
@dynamic playerId;
@dynamic updateDate;


// Delete every persisted OverScoreData row (called by -[UserSettingData initForConvert]).
+ (void)deleteAll:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"OverScoreData" inManagedObjectContext:context];
    NSArray *all = [context executeFetchRequest:request error:NULL];
    for (NSManagedObject *object in all) {
        [context deleteObject:object];
    }
}

@end
