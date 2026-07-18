//
//  neDebugLog.h
//  pop'n rhythmin
//
//  Optional render-pipeline diagnostics. Emits os_log lines tagged "RHYDBG" so
//  they can be captured on device with:  idevicesyslog | grep RHYDBG
//
//  This code is NOT part of the original binary. It is compiled in only when the
//  build defines RHYDBG (see the RHYDBG CMake option, which is enable-able in any
//  build configuration and is turned on in CI). With RHYDBG off the helpers below
//  collapse to no-ops, so every translation unit that only logs matches the
//  reconstructed original exactly -- WITHOUT any `#if RHYDBG` at the call site:
//
//    * neDebugLog(...) becomes an empty inline, so a bare log call vanishes.
//    * NE_DBG_FIRST(n) becomes `(false)`, so an `if (NE_DBG_FIRST(n)) { ... }`
//      block turns into `if (false) { ... }` and is dead-code-eliminated;
//      debug-only locals declared inside the block stay "used" within it, so
//      -Werror stays quiet. Put all diagnostic work inside that block.
//    * NE_DBG(...) wraps debug statements that have real side effects we must NOT
//      run in the faithful build (e.g. glGetError(), which clears GL error state).
//      It expands to the statements when RHYDBG is on and to nothing otherwise.
//

#pragma once

#ifndef RHYDBG
#define RHYDBG 0
#endif

#if RHYDBG

#include <cstdarg>
#include <cstdio>

#include <os/log.h>

// printf-style wrapper over os_log (works in both .cpp and .mm translation
// units; os_log lines are what idevicesyslog captures).
static inline void neDebugLog(const char *fmt, ...) {
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    os_log(OS_LOG_DEFAULT, "RHYDBG %{public}s", buf);
}

// A call counter helper: returns true for the first `limit` invocations at a
// given site, so a per-frame draw call can log a bounded burst instead of
// flooding the log at 60 fps.
#define NE_DBG_FIRST(limit)                                                                        \
    ([]() -> bool {                                                                                \
        static int _c = 0;                                                                         \
        return _c < (limit) ? (++_c, true) : false;                                                \
    }())

// Wrap debug-only statements with real side effects. Internal `;` separates
// multiple statements; the macro supplies the trailing one.
#define NE_DBG(...)                                                                                \
    do {                                                                                           \
        __VA_ARGS__;                                                                               \
    } while (0)

#else

// No-op fallbacks: a bare, unguarded log call still compiles away to nothing,
// and NE_DBG_FIRST(n) collapses an `if (...) { ... }` diagnostic block to dead
// code that the optimiser drops.
static inline void neDebugLog(const char *, ...) {
}
#define NE_DBG_FIRST(limit) (false)
#define NE_DBG(...) ((void)0)

#endif

// The build's git SHA (set by CMake at configure time). Logged once at startup
// under RHYDBG so a captured os_log identifies exactly which build produced it.
#ifndef RHYDBG_BUILD_SHA
#define RHYDBG_BUILD_SHA "unknown"
#endif

// kate: hl C++;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
