# CMakeLists.txt — pop'n rhythmin (PopnRhythmin) reconstruction  (root)
#
# The original game shipped ONLY as a 32-bit (armv7) binary, which is exactly why it
# cannot run on iOS 11+ (64-bit only). The point of this reconstruction is to rebuild
# it so it CAN run there: we produce a fat binary spanning the legacy 32-bit slices
# AND modern 64-bit ones —  armv7 armv7s arm64 arm64e  — by default.
#
# Your installed toolchain decides which slices are actually achievable:
#   * armv7 / armv7s  need Xcode <= 11 (dropped in Xcode 12).
#   * arm64           builds on essentially any modern Xcode.
#   * arm64e          needs a recent Xcode with arm64e *app* codegen (>= ~11) and
#                     iOS >= 12.1; drop it if your SDK rejects it.
# Override with -DIOS_ARCHS="arm64" (etc.) to match what you have.
#
# This file builds a NATIVE iOS .app. Configure with `-G Xcode` plus the leetal/ios-cmake
# toolchain to build the .app target from the per-directory source tree.
#
#   cmake -G Xcode -DCMAKE_TOOLCHAIN_FILE=/path/to/ios.toolchain.cmake -DPLATFORM=OS64 ..
#
# Theos is supported too, but NOT through CMake: it has its own hand-maintained, fixed
# Theos application Makefile under ./theos/ (build with `make -C theos`). See theos/Makefile.
#
# Deployment floor: a fat armv7+arm64 binary can carry a low MinimumOSVersion (the
# arm64 slice simply won't load on the <iOS7 devices that only exist in 32-bit). We
# default to 5.1.1 for maximum legacy reach; arm64e realistically wants >= 12.1.
#
# Every knob below is a CACHE entry, so ALL of them (bundle id, name, version, archs,
# deployment target, tool paths) are overridable on the command line with -D<name>=..

cmake_minimum_required(VERSION 3.14)

project(PopnRhythmin
        VERSION 2.0.3
        LANGUAGES C CXX OBJC OBJCXX)

# ---------------------------------------------------------------------------
# User-facing options (all overridable via -D...)
# ---------------------------------------------------------------------------
set(IOS_ARCHS "armv7 armv7s arm64 arm64e" CACHE STRING "Space-separated architecture slices")
set(IOS_DEPLOYMENT_TARGET "5.1.1" CACHE STRING "Minimum iOS version (fat-binary floor)")
if(DEFINED DEPLOYMENT_TARGET)                 # leetal/ios-cmake spelling
    set(IOS_DEPLOYMENT_TARGET "${DEPLOYMENT_TARGET}")
endif()

set(XCODE_PATH ""            CACHE PATH "Path to Xcode developer dir (blank = xcode-select)")

set(APP_BUNDLE_ID    "jp.co.konami.popnrhythmin" CACHE STRING "CFBundleIdentifier")
set(APP_DISPLAY_NAME "pop'n rhythmin"            CACHE STRING "CFBundleDisplayName")
set(APP_VERSION      "2.0.3"                      CACHE STRING "CFBundleShortVersionString")
set(APP_BUILD        "2.0.3"                      CACHE STRING "CFBundleVersion")
set(RESOURCES_DIR    "" CACHE PATH "Directory of the ORIGINAL extracted .app whose resources "
                                   "(images, rhythmin.lv, .acv/.orb/.idx, fonts, ...) are copied "
                                   "verbatim into the built bundle. Leave empty to build code only.")

# RHYDBG compiles in the optional render-pipeline os_log diagnostics (tagged
# "RHYDBG"; see Project/System/src/Render/neDebugLog.h). It is NOT part of the
# original binary, so it defaults OFF and the shipped build matches the binary.
# It is a plain cache option, so it can be enabled in ANY build configuration
# with -DRHYDBG=ON.
option(RHYDBG "Compile in the RHYDBG render-pipeline diagnostics (os_log)" OFF)

# ENABLE_PATCHES compiles in preservation patches that bypass flows depending on
# Konami's now-defunct online services (the first-run Terms-of-Service acceptance
# and the download file-list fetch). It is NOT part of the original binary, so it
# defaults OFF and the shipped build matches the binary. It is a plain cache
# option, enable-able in ANY build configuration with -DENABLE_PATCHES=ON. Guard
# ONLY dead-server behaviour with it; genuine modern-iOS layout corrections (e.g.
# safe-area insets) belong in the always-on code path, not behind this flag.
option(ENABLE_PATCHES "Compile in offline-preservation patches (skip dead service flows)" OFF)

# ENABLE_OFFLINE_PATCHES is a heavier, separate category. Where ENABLE_PATCHES
# only skips or repairs dead-server UI flows (and otherwise lets network calls
# fail naturally), ENABLE_OFFLINE_PATCHES makes a normally-online step actually
# complete offline by faking its success locally — currently the player-name
# registration, which the retired server can no longer acknowledge. It is opt-in
# independently of ENABLE_PATCHES, defaults OFF, and is enable-able in any build
# configuration with -DENABLE_OFFLINE_PATCHES=ON.
option(ENABLE_OFFLINE_PATCHES "Compile in offline stand-ins for retired online steps (local name registration)" OFF)

# Server hosts the game contacts. The defaults are the original (now-defunct)
# Konami hosts, so a faithful build is byte-for-byte unchanged. Override them to
# point a rebuild at a private/revival server, e.g. -D APR_SECURE_HOST=my.host.
# When ENABLE_PATCHES is on these are only the DEFAULTS; a value stored in the
# app's preferences .plist (keys AprHost / AprSecureHost / OfficialHost) wins.
set(APR_HOST "apr.konaminet.jp" CACHE STRING "Game-API host (http)")
set(APR_SECURE_HOST "apr.s.konaminet.jp" CACHE STRING "Game-API host (https)")
set(OFFICIAL_HOST "p.eagate.573.jp" CACHE STRING "Official / eagate host (http)")
set(KONAMI_ID_HOST "id.konami.net" CACHE STRING "Konami ID host (https)")

# ---------------------------------------------------------------------------
# Toolchain discovery (informational)
# ---------------------------------------------------------------------------
if(NOT XCODE_PATH)
    find_program(XCODE_SELECT xcode-select)
    if(XCODE_SELECT)
        execute_process(COMMAND ${XCODE_SELECT} -p
                        OUTPUT_VARIABLE _xcp OUTPUT_STRIP_TRAILING_WHITESPACE
                        ERROR_QUIET RESULT_VARIABLE _xcr)
        if(_xcr EQUAL 0 AND _xcp)
            set(XCODE_PATH "${_xcp}")
        endif()
    endif()
endif()
if(XCODE_PATH AND EXISTS "${XCODE_PATH}")
    message(STATUS "PopnRhythmin: found Xcode/developer dir at ${XCODE_PATH}")
endif()
message(STATUS "PopnRhythmin: archs='${IOS_ARCHS}' iOS>=${IOS_DEPLOYMENT_TARGET}")

# Frameworks actually #import-ed across the sources.
set(SYS_FRAMEWORKS
    UIKit Foundation CoreGraphics QuartzCore CoreText
    OpenGLES AudioToolbox AVFoundation
    CoreData StoreKit Social
    Security SystemConfiguration CFNetwork
    GameKit AdSupport CoreLocation MapKit
    WebKit UserNotifications)

# =========================================================================
# NATIVE / Xcode — real .app target, fed by per-directory CMakeLists.
# =========================================================================
# Build the App Transport Security block substituted into Info.plist. Modern iOS
# blocks cleartext and weak TLS by default, so declare a per-host exception for
# each configured server (a revival server may present an imperfect cert). Hosts
# are deduplicated: pointing every host at one server emits a single domain entry
# (duplicate keys would be invalid plist). Under ENABLE_PATCHES the host can also
# be overridden at runtime to something not known here, so arbitrary loads are
# additionally allowed in that build.
set(_ats_hosts "${APR_HOST}" "${APR_SECURE_HOST}" "${OFFICIAL_HOST}" "${KONAMI_ID_HOST}")
list(REMOVE_DUPLICATES _ats_hosts)
set(_ats_domains "")
foreach(_h IN LISTS _ats_hosts)
  string(APPEND _ats_domains
"            <key>${_h}</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSExceptionMinimumTLSVersion</key>
                <string>TLSv1.0</string>
                <key>NSExceptionRequiresForwardSecrecy</key>
                <false/>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
")
endforeach()
if(ENABLE_PATCHES)
  set(_ats_arbitrary "        <key>NSAllowsArbitraryLoads</key>
        <true/>
")
else()
  set(_ats_arbitrary "")
endif()
set(APP_TRANSPORT_SECURITY
"    <key>NSAppTransportSecurity</key>
    <dict>
${_ats_arbitrary}        <key>NSExceptionDomains</key>
        <dict>
${_ats_domains}        </dict>
    </dict>")

set(INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/Info.plist")
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in" "${INFO_PLIST}" @ONLY)

# Single app target, fed by per-directory CMakeLists (each appends its own translation
# units via target_sources(popnrhythmin ...) and puts its dir on the include path).
#
# NOTE: per-directory STATIC LIBRARIES were tried and reverted. Unlike C, Objective-C
# classes referenced only by name/selector (NSStringFromClass, imageNamed:, string-keyed
# lookups) carry no link-time reference, so the linker strips whole classes/categories out
# of a static archive — you have to paper over it with -force_load/-ObjC. That is not the
# clean "C static lib" model, so we keep one translation-unit set in a single target.
add_executable(popnrhythmin MACOSX_BUNDLE)
target_include_directories(popnrhythmin PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/Project")

# -------------------------------------------------------------------------
# Sugoroku board character-message dialogue.
# The ~330 board-dialogue strings are copyrighted game content and are NOT in this
# source tree. At configure time we generate the six static `const char*` tables that
# Project/Game/Data/TreasureMap/TreasureMap.mm #includes, by running the extractor
# against an owned app binary. Point at your binary to embed the real text:
#     cmake -DPOPNRHYTHMIN_BINARY=/path/to/Payload/PopnRhythmin.app/PopnRhythmin ...
# With no binary set, empty tables are generated and the board messages render blank.
# -------------------------------------------------------------------------
find_program(PYTHON3_EXECUTABLE NAMES python3 python)
set(POPNRHYTHMIN_BINARY "" CACHE FILEPATH
    "Owned PopnRhythmin app binary; embeds the sugoroku board dialogue when set.")
set(_sugo_gen_dir "${CMAKE_CURRENT_BINARY_DIR}/generated")
set(_sugo_gen_inc "${_sugo_gen_dir}/sugoroku_chara_msg.generated.inc")
set(_sugo_script  "${CMAKE_CURRENT_SOURCE_DIR}/tools/extract_sugoroku_dialogue.py")
file(MAKE_DIRECTORY "${_sugo_gen_dir}")
if(PYTHON3_EXECUTABLE)
    if(POPNRHYTHMIN_BINARY AND EXISTS "${POPNRHYTHMIN_BINARY}")
        execute_process(
            COMMAND "${PYTHON3_EXECUTABLE}" "${_sugo_script}"
                    --format c "${POPNRHYTHMIN_BINARY}" "${_sugo_gen_inc}"
            RESULT_VARIABLE _sugo_rc OUTPUT_VARIABLE _sugo_out ERROR_VARIABLE _sugo_out)
        if(_sugo_rc EQUAL 0)
            message(STATUS "PopnRhythmin: embedded sugoroku dialogue from ${POPNRHYTHMIN_BINARY}")
        else()
            message(WARNING "PopnRhythmin: dialogue extraction failed:\n${_sugo_out}\nUsing empty tables.")
            execute_process(COMMAND "${PYTHON3_EXECUTABLE}" "${_sugo_script}" --emit-empty "${_sugo_gen_inc}")
        endif()
    else()
        message(STATUS "PopnRhythmin: POPNRHYTHMIN_BINARY not set -> empty sugoroku dialogue "
                       "(board character messages blank). Set it to embed the real text.")
        execute_process(COMMAND "${PYTHON3_EXECUTABLE}" "${_sugo_script}" --emit-empty "${_sugo_gen_inc}")
    endif()
else()
    message(WARNING "PopnRhythmin: python3 not found -> empty sugoroku dialogue tables.")
    file(WRITE "${_sugo_gen_inc}" "// python3 unavailable at configure time; empty tables.\n")
    foreach(_pair "kCharGroup6Slot0 41" "kCharGroup6Slot1 35" "kCharGroup6Slot2 47"
                  "kCharGroup8Slot0 64" "kCharGroup8Slot1 72" "kCharGroup8Slot2 71")
        separate_arguments(_pl UNIX_COMMAND "${_pair}")
        list(GET _pl 0 _nm)
        list(GET _pl 1 _ct)
        file(APPEND "${_sugo_gen_inc}" "static const char *const ${_nm}[${_ct}] = {0};\n")
    endforeach()
endif()
target_include_directories(popnrhythmin PRIVATE "${_sugo_gen_dir}")

add_subdirectory(Project)

# --- Vendored ZipArchive / minizip (3rdparty/) --------------------------------------------
# Provides the UnZipArchive class the music-data loaders use for .zip chart extraction (Google
# Code "ziparchive" snapshot, ~2014). UnZipArchive.mm is ARC-converted; minizip is plain C.
set(_zip "${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/ziparchive")
target_sources(popnrhythmin PRIVATE
    "${_zip}/UnZipArchive.mm"
    "${_zip}/minizip/ioapi.c"
    "${_zip}/minizip/unzip.c"
    "${_zip}/minizip/zip.c")
target_include_directories(popnrhythmin PRIVATE "${_zip}" "${_zip}/minizip")
# minizip is vendored upstream C we do not patch; silence its extraneous
# parentheses-equality warnings (e.g. zip.c's `if ((level==2))`) without
# touching the third-party source.
set_source_files_properties(
    "${_zip}/minizip/ioapi.c"
    "${_zip}/minizip/unzip.c"
    "${_zip}/minizip/zip.c"
    PROPERTIES COMPILE_OPTIONS "-Wno-parentheses-equality")

# ARC and ObjC-ARC exceptions are turned on through the Xcode build settings
# (CLANG_ENABLE_OBJC_ARC / CLANG_ENABLE_OBJC_ARC_EXCEPTIONS below), which scope
# themselves to the Objective-C languages, so no -fobjc-arc / -fobjc-exceptions
# compile flags are needed here (they would only warn on the plain C sources).
# The reconstruction faithfully uses the OpenGL ES 1.1 API, which Apple
# deprecated wholesale on iOS 12 with no in-place replacement (Metal is a
# separate stack). Silence the blanket ES deprecation warnings rather than
# rewrite the renderer.
target_compile_definitions(popnrhythmin PRIVATE GLES_SILENCE_DEPRECATION)

# When RHYDBG is enabled, define it for every translation unit; the generator
# expression is config-agnostic, so it applies in Debug, Release, and any other
# configuration alike.
target_compile_definitions(popnrhythmin PRIVATE $<$<BOOL:${RHYDBG}>:RHYDBG=1>)
target_compile_definitions(popnrhythmin PRIVATE $<$<BOOL:${ENABLE_PATCHES}>:ENABLE_PATCHES=1>)
target_compile_definitions(popnrhythmin
                           PRIVATE $<$<BOOL:${ENABLE_OFFLINE_PATCHES}>:ENABLE_OFFLINE_PATCHES=1>)

# Configurable server hosts (see the APR_HOST / APR_SECURE_HOST / OFFICIAL_HOST
# cache variables above). Passed as quoted C string literals; StoreUtil.m falls
# back to the same defaults when these are not defined.
target_compile_definitions(popnrhythmin PRIVATE
                           APR_HOST="${APR_HOST}"
                           APR_SECURE_HOST="${APR_SECURE_HOST}"
                           OFFICIAL_HOST="${OFFICIAL_HOST}"
                           KONAMI_ID_HOST="${KONAMI_ID_HOST}")

set_target_properties(popnrhythmin PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${INFO_PLIST}"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${APP_BUNDLE_ID}"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "${IOS_DEPLOYMENT_TARGET}"
    XCODE_ATTRIBUTE_ARCHS "${IOS_ARCHS}"
    XCODE_ATTRIBUTE_VALID_ARCHS "${IOS_ARCHS}"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH "NO"
    XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
    XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES"
    XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC_EXCEPTIONS "YES"
    XCODE_ATTRIBUTE_CLANG_ENABLE_STACK_ZERO_INIT "YES"
    XCODE_ATTRIBUTE_GCC_C_LANGUAGE_STANDARD "gnu2x"
    XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD "gnu++2b"
    XCODE_ATTRIBUTE_CLANG_CXX_LIBRARY "libc++"
    # This build is never submitted to the App Store.
    XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_SKIP_APP_STORE_DEPLOYMENT "YES"
    # Turn the static analyzer's checkers on.
    XCODE_ATTRIBUTE_CLANG_ANALYZER_LOCALIZABILITY_EMPTY_CONTEXT "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_DIVIDE_BY_ZERO "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_DEADCODE_DEADSTORES "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_NONNULL "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_NULL_DEREFERENCE "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_ATSYNC "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_COLLECTIONS "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_GENERICS "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_INCOMP_METHOD_TYPES "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_NSCFERROR "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_SELF_INIT "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_UNUSED_IVARS "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_SECURITY_BUFFER_OVERFLOW_EXPERIMENTAL "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_SECURITY_FLOATLOOPCOUNTER "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_USE_AFTER_MOVE "YES"
    # Run the static analyzer in its deep (cross-function) mode.
    XCODE_ATTRIBUTE_CLANG_STATIC_ANALYZER_MODE "Deep"
    XCODE_ATTRIBUTE_CLANG_STATIC_ANALYZER_MODE_ON_ANALYZE_ACTION "Deep"
    # Extra clang-tidy bugprone checks.
    XCODE_ATTRIBUTE_CLANG_TIDY_BUGPRONE_ASSERT_SIDE_EFFECT "YES"
    XCODE_ATTRIBUTE_CLANG_TIDY_BUGPRONE_INFINITE_LOOP "YES"
    XCODE_ATTRIBUTE_CLANG_TIDY_BUGPRONE_MOVE_FORWARDING_REFERENCE "YES"
    OUTPUT_NAME "PopnRhythmin")

foreach(_fw ${SYS_FRAMEWORKS})
    find_library(FW_${_fw} ${_fw})
    if(FW_${_fw})
        target_link_libraries(popnrhythmin PRIVATE ${FW_${_fw}})
    else()
        target_link_libraries(popnrhythmin PRIVATE "-framework ${_fw}")
    endif()
endforeach()
target_link_libraries(popnrhythmin PRIVATE z)   # CommonCrypto is in libSystem; zlib for asset unpack

if(RESOURCES_DIR AND EXISTS "${RESOURCES_DIR}")
    file(GLOB RES_ENTRIES "${RESOURCES_DIR}/*")
    foreach(_res ${RES_ENTRIES})
        get_filename_component(_name "${_res}" NAME)
        if(NOT _name MATCHES "^(PopnRhythmin|_CodeSignature|CodeResources|embedded\\.mobileprovision|Info\\.plist)$")
            target_sources(popnrhythmin PRIVATE "${_res}")
            set_source_files_properties("${_res}" PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
        endif()
    endforeach()
    message(STATUS "PopnRhythmin: bundling resources from ${RESOURCES_DIR}")
else()
    message(WARNING "PopnRhythmin: RESOURCES_DIR not set — building CODE ONLY (links, but no assets).")
endif()

# kate: hl CMake; replace-tabs on; indent-width 4; tab-width 4;
