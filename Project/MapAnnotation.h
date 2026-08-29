/**
 * @file
 * A map pin for the arcade-locator map.
 *
 * An MKAnnotation carrying a coordinate, a title and subtitle, and the arcade's model name.
 * Reconstructed from Ghidra project rb420, program PopnRhythmin
 * (initWithCoordinate:Title:SubTitle:Model: @ 0x850e4, dealloc @ 0x851c8, setCoordinate: @
 * 0x85264, modelName @ 0x85288, coordinate @ 0x85298, title @ 0x852b0, subtitle @ 0x852c4).
 *
 * The binary's Objective-C metadata gives the superclass as NSObject, adopting `<MKAnnotation>`.
 */

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

/**
 * One arcade-search map pin.
 */
@interface MapAnnotation : NSObject <MKAnnotation>

/**
 * Store the coordinate by value, and copies of the title, subtitle and model strings.
 * @param coordinate The pin's location.
 * @param title The callout title.
 * @param subtitle The callout subtitle.
 * @param model The arcade's cabinet model name.
 * @return The initialised annotation.
 */
- (id)initWithCoordinate:(CLLocationCoordinate2D)coordinate
                   Title:(NSString *)title
                SubTitle:(NSString *)subtitle
                   Model:(NSString *)model;

/** The pin's location. It is read/write here, since the class ships -setCoordinate:. */
@property(nonatomic) CLLocationCoordinate2D coordinate;
/** The callout title. */
@property(nonatomic, readonly, copy) NSString *title;
/** The callout subtitle. */
@property(nonatomic, readonly, copy) NSString *subtitle;

/**
 * The arcade's cabinet model name; an extra accessor outside MKAnnotation.
 * @return The model name.
 */
- (NSString *)modelName;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
