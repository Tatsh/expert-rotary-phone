//
//  neDebugLog.h
//  pop'n rhythmin
//
//  TEMPORARY render-pipeline diagnostics. Emits os_log lines tagged "RHYDBG" so
//  they can be captured on device with:  idevicesyslog | grep RHYDBG
//  Remove before the reconstruction is considered done.
//

#pragma once

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

// kate: hl C++;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
