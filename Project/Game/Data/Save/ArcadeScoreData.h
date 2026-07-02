//
//  ArcadeScoreData.h
//  pop'n rhythmin
//
//  Core Data managed object.
//  Reconstructed from ScoreData.momd/ScoreData_v2.mom (entity "ArcadeScoreData").
//
//  Mirror of arcade-machine ("AC") song records fetched from the network:
//  per-song personal best (my*), venue mean (mean*) and venue top (top*)
//  scores across four arcade difficulties — Easy (Es), Normal (N), Hyper (H)
//  and EX — plus the name of whoever holds the top score at each difficulty.
//
//  Numeric attributes are NSNumber-backed (non-scalar Core Data codegen; see
//  ScoreData.h for the confirming call site). Storage width noted per property.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface ArcadeScoreData : NSManagedObject

@property (nonatomic, retain) NSNumber *musicId;      // Integer16
@property (nonatomic, retain) NSNumber *category;     // Integer16
@property (nonatomic, retain) NSString *refId;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *genre;
@property (nonatomic, retain) NSDate *updateDate;

@property (nonatomic, retain) NSNumber *myScoreEs;    // Integer32
@property (nonatomic, retain) NSNumber *myScoreN;     // Integer32
@property (nonatomic, retain) NSNumber *myScoreH;     // Integer32
@property (nonatomic, retain) NSNumber *myScoreEx;    // Integer32

@property (nonatomic, retain) NSNumber *meanScoreEs;  // Integer32
@property (nonatomic, retain) NSNumber *meanScoreN;   // Integer32
@property (nonatomic, retain) NSNumber *meanScoreH;   // Integer32
@property (nonatomic, retain) NSNumber *meanScoreEx;  // Integer32

@property (nonatomic, retain) NSNumber *topScoreEs;   // Integer32
@property (nonatomic, retain) NSNumber *topScoreN;    // Integer32
@property (nonatomic, retain) NSNumber *topScoreH;    // Integer32
@property (nonatomic, retain) NSNumber *topScoreEx;   // Integer32

@property (nonatomic, retain) NSString *topNameEs;
@property (nonatomic, retain) NSString *topNameN;
@property (nonatomic, retain) NSString *topNameH;
@property (nonatomic, retain) NSString *topNameEx;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
