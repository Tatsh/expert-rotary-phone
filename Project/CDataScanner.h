//
//  CDataScanner.h
//  pop'n rhythmin
//
//  TouchJSON raw byte-cursor scanner over an NSData. It walks a UTF-8 byte
//  buffer with three `const char *` cursors (start/end/current) and provides
//  the low-level scanning primitives (scan a literal string, scan characters
//  from a set, scan up to a string/set, scan a number, skip whitespace, scan
//  C / C++ style comments). CJSONScanner is a subclass that layers the JSON
//  grammar on top and reads the @protected `current`/`end` cursors directly.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//
//  Superclass determined from Ghidra: init/dealloc chain up to NSObject
//  (class_ro superclass = NSObject); init/dealloc call NSObject::init /
//  NSObject::dealloc.
//
//  ivars decoded from Ghidra (setData: @ 0x648a0):
//    data             NSData*          — retained backing data
//    start            const char*      — data.bytes (buffer origin)
//    end              const char*      — start + data.length (one past last)
//    current          const char*      — the moving byte cursor
//    length           unsigned         — data.length
//    doubleCharacters NSCharacterSet*  — set of characters valid in a number
//  NOTE: start/end/current are byte POINTERS into data.bytes, not char values.
//

#import <Foundation/Foundation.h>

@interface CDataScanner : NSObject {
@protected
    NSData *data;
    const char *start;
    const char *end;
    const char *current;
    unsigned length;
    NSCharacterSet *doubleCharacters;
}

+ (id)scannerWithData:(NSData *)inData;

- (NSData *)data;
- (void)setData:(NSData *)inData;

- (NSCharacterSet *)doubleCharacters;
- (void)setDoubleCharacters:(NSCharacterSet *)inDoubleCharacters;

- (NSUInteger)scanLocation;
- (void)setScanLocation:(NSUInteger)inScanLocation;
- (BOOL)isAtEnd;

- (unichar)currentCharacter;
- (unichar)scanCharacter;
- (BOOL)scanCharacter:(unichar)inCharacter;

- (BOOL)scanUTF8String:(const char *)inString intoString:(NSString **)outString;
- (BOOL)scanString:(NSString *)inString intoString:(NSString **)outString;
- (BOOL)scanCharactersFromSet:(NSCharacterSet *)inSet intoString:(NSString **)outString;
- (BOOL)scanUpToString:(NSString *)inString intoString:(NSString **)outString;
- (BOOL)scanUpToCharactersFromSet:(NSCharacterSet *)inSet intoString:(NSString **)outString;
- (BOOL)scanNumber:(NSNumber **)outNumber;

- (void)skipWhitespace;
- (NSString *)remainingString;

- (BOOL)scanCStyleComment:(NSString **)outComment;
- (BOOL)scanCPlusPlusStyleComment:(NSString **)outComment;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
