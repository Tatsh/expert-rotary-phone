/**
 * @file
 * @brief A TouchJSON wrapper around an NSData blob that is already-serialized JSON.
 *
 * When handed to CJSONDataSerializer it is emitted verbatim instead of being re-encoded.
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON; initWithData: @
 * 0x6a4c4, data @ 0x6a540).
 */

#import <Foundation/Foundation.h>

/**
 * @brief A wrapper around an NSData blob that is already serialized JSON; CJSONDataSerializer
 * emits it verbatim instead of re-encoding it.
 */
@interface CSerializedJSONData : NSObject {
    NSData *data; /**< The already-serialized JSON bytes. */
}

/**
 * @brief Wrap already-serialized JSON bytes.
 * @param inData The JSON bytes.
 * @return The initialised wrapper.
 * @ghidraAddress 0x6a4c4
 */
- (id)initWithData:(NSData *)inData;
/**
 * @brief The wrapped JSON bytes.
 * @return The bytes, emitted verbatim by the serializer.
 * @ghidraAddress 0x6a540
 */
- (NSData *)data;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
