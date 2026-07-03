//
//  CJSONScanner.h
//  pop'n rhythmin
//
//  TouchJSON recursive-descent JSON parser. It is a subclass of CDataScanner
//  (the raw byte-cursor scanner over an NSData) and adds the JSON grammar:
//  objects, dictionaries, arrays, string constants (with escape handling) and
//  number constants.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//  (scanJSONObject:error: @ 0x678d0, setData: @ 0x677cc).
//
//  Superclass determined from Ghidra: init/dealloc/setData: chain up to
//  CDataScanner, and scanNotQuoteCharactersIntoString: reads CDataScanner's
//  `current`/`end` byte-cursor ivars directly.
//  TODO(dep): CDataScanner — the byte-cursor scanner superclass is itself
//  missing and must be reconstructed separately; it supplies scannerWithData:,
//  skipWhitespace, currentCharacter, scanCharacter, scanCharacter:,
//  scanLocation, setScanLocation:, scanNumber:, scanUTF8String:intoString: and
//  the protected `current`/`end` ivars used below.
//

#import <Foundation/Foundation.h>

// TODO(dep): CDataScanner — reconstruct separately (missing from this pass).
#import "CDataScanner.h"

@interface CJSONScanner : CDataScanner {
    BOOL strictEscapeCodes;
}

- (BOOL)scanJSONObject:(id *)outObject error:(NSError **)outError;
- (BOOL)scanJSONDictionary:(NSDictionary **)outDictionary error:(NSError **)outError;
- (BOOL)scanJSONArray:(NSArray **)outArray error:(NSError **)outError;
- (BOOL)scanJSONStringConstant:(NSString **)outStringConstant error:(NSError **)outError;
- (BOOL)scanJSONNumberConstant:(NSNumber **)outNumber error:(NSError **)outError;
- (BOOL)scanNotQuoteCharactersIntoString:(NSString **)outString;
- (BOOL)strictEscapeCodes;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
