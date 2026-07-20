# C/C++/Objective-C guidelines

## General

- 4 space indents with no tabs.
- Avoid magic numbers: create constants and enumerations for all numbers that are not obvious (e.g.,
  `kMaxPlayers` instead of `4`). This includes creating enumerations for array indices and bit
  flags.
- By default use decimal integer literals unless hex is required for bitwise operations or when it
  genuinely aids readability.
- Use `.h` extension for all headers regardless of language.
- Include grouping: the file's own header first, then system, first party (Apple, etc), third party,
  and ours (in double quotes). Each group is separated by a single blank line:

  ```c
  #import "ThisFile.h"

  #include <memory>

  #include <CoreFoundation/CoreFoundation.h>

  #include <OtherThirdParty.h>
  #include <TouchJSON.h>

  #include "OurFile.h"
  ```

  `clang-format` enforces this (`IncludeBlocks: Regroup`): it moves the file's own header to the top
  and inserts the blank line between each group. This project should not have anything that requires
  a specific header order beyond this.

- Keep all header groups sorted alphabetically.
- Use `clang-format` to format source files. Shortcut: `yarn format`.
- This project uses Doxygen to document members. Always document public members in headers.
- Tie a reconstructed routine to its binary function with the `@ghidraAddress 0x...` Doxygen tag (a
  custom tag in our Doxygen configuration) on its header declaration; the address is relative to the
  PopnRhythmin program's image base. In an implementation file this tag appears only inside a block
  body (see the Objective-C block rule).
- Use attached braces. `if () {` not `if ()\n{`.
- _Always_ include curly braces.
- Use parentheses to group expressions.
- When an assignment appears in a condition, wrap it in double parentheses (e.g.
  `if ((p = next()))`); generally avoid assignment inside conditions.
- `*` go to the right of the type. `int *a` not `int* a`.
- Prefer to use pre-increments: `++i` not `i++`.
- Always keep `theos/Makefile` synced with the `CMake` files.
- If a structure member is a bit-field, declare the width (number of bits).
- Use British spelling in comments and documentation; use American spelling for identifiers.

## Reconstruction fidelity

This tree reconstructs a decompiled binary; beyond the `@ghidraAddress` citation rule above, keep
reconstructed code faithful to the original.

- Keep the binary's names. Reconstructed globals keep their Ghidra names (for example the
  `g_`-prefixed globals). Ghidra placeholder names (`FUN_*`, `DAT_*`, `PTR_*`) are never used as
  identifiers in reconstructed code; rename them descriptively and record the address with
  `@ghidraAddress`.
- Model real types, not decompiler artifacts. Use real struct fields (never `field_0xNN`) and real
  pointer, enum, and `BOOL` types (never `void *` for a typed pointer, an `int` that holds a
  pointer, or `undefined`/`undefined4`).
- Document the original 32-bit struct layout with trailing `// +0xNN` offset comments, but treat
  those offsets as documentation only: do not `#pragma pack` or `static_assert` the layout, and
  never read or write a struct by a hardcoded offset. The 32-bit offsets do not hold on the 64-bit
  target, so always go through named fields.
- `reinterpret_cast` is a smell: it usually hides a type or signature bug, especially a
  function-pointer callback ABI. Prefer real types and typed access, and replace such casts at crash
  sites.

## C

- Use `#ifndef UPPERCASE_NAME_H` (all-caps) header guards.
- Use `snake_case` for identifiers.
- Wrap C headers in `extern "C"` (guarded by `#ifdef __cplusplus`) so their symbols are not subject
  to C++ name mangling.

## C++

- Use `#pragma once` as the header guard.
- Use `#ifdef __OBJC__` to wrap Objective-C++ code in C++ unless the implementation file extension
  is `.mm` (Objective-C++). This allows the header to be included in pure C++ files without errors.
- Liberally use `auto` and `const auto&` for type inference, especially for iterators and STL
  containers.
- Use the `.cpp` extension only for pure C++ (no Objective-C). Any file that mixes C++ with
  Objective-C uses `.mm`; any header that declares C++ used from Objective-C is `.h` (see the
  `#ifdef __OBJC__` rule above).
- Name classes in CamelCase where acronyms become title-case (ID becomes Id).
- If a class name is available in the RTTI use it for the name.
- `delete` is only used when it is what the original did and the same behaviour cannot be achieved
  with smart pointers. Otherwise smart pointers are highly encouraged.
- Always use C++-style casts.
- `*` and `&` go to the right of the type. `int &a` not `int& a`.
- Use `__builtin_available()` to check for API availability. Prefer runtime checks over
  compile-time.
- Use `= {}` to zero initialise class members.
- Use `m_` prefix to name class members.
- Prefer to use zero-init constructors whenever possible.

## Objective-C

- Due to how Objective-C works at runtime, the binary documents all class, ivar, property, and
  method names. This project strictly uses those names.
- New code follows Apple's conventions: a class name gets a two-character prefix and all identifiers
  use `CamelCase` but retain all uppercase letters (`JSON` not `Json`).
- Private identifiers get a `_` prefix.
- This project uses ARC and has no support for Manual Reference Counting (MRC). Do not use `retain`,
  `release`, or `autorelease`. When the binary's MRC transfers ownership into a field (a `-copy` or
  `retain` that a later `release` balances), model it with a `strong` reference, not
  `__unsafe_unretained`.
- Null literals by language: use `nil` for Objective-C objects and `nullptr` for C and C++ pointers
  in `.mm`, `.cpp`, and `.h` files. Avoid `NULL`.
- Use `#import` for all imports.
- Use only Objective-C 2.0 constructs including properties, dot syntax, fast enumeration, blocks,
  and boxed literals.
- Use `#pragma mark` (and `#pragma mark -` for a divider) to group an implementation into sections.
- Reconstruct getters and setters as `@property` declarations (add `@synthesize` only when the
  binary keeps a differently-named backing ivar), not spelled-out accessor bodies. Map the compiled
  accessor to its attribute: `assign`, `strong` (retain), or `copy`, and `atomic` or `nonatomic`.
- Create enumerations with `NS_ENUM` and `NS_OPTIONS` macros.
- Create constants with k-prefixes for global constants and static const for file-level constants.
  Use `NSString *const` for string constants.
- Use `@available()` to check for API availability. Prefer runtime checks over compile-time.
- Headers: always add modelines to the end of the file:

  ```objc
  // code: language=Objective-C
  // kate: hl Objective-C;
  // vim: set ft=objc :
  ```

  Use `language=Objective-C++`, `hl Objective-C++`, and `ft=objcpp` for Objective-C++ headers.

- If a block is directly tied to a function in the binary, use `@ghidraAddress 0x...` to document
  that.

  ```objc
  [doSomethingWithBlock:^{
    /** @ghidraAddress 0x1234 */
    // code here
  }]
  ```
