/** @file
 * The app's shared UI typeface names. C-linkage (defined in AppFont.m) so the C++ (.mm) callers
 * resolve the unmangled symbols.
 */

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief The bundled DynaFont face used for the app's UI text.
 * @return The name of the app font.
 * @ghidraAddress 0x5ef9c
 */
NSString *AppFontName(void);
/**
 * @brief The bundled DynaFont maru face used for the "maru" text in the app.
 * @return The name of the maru font.
 * @ghidraAddress 0x5efa8
 */
NSString *AppMaruFontName(void);

#ifdef __cplusplus
}
#endif

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
