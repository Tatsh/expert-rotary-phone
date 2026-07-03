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
# This file ADAPTS to your build environment:
#   * THEOS — if a Theos install is found (env $THEOS / -DTHEOS=.. / usual locations),
#             generates a ready-to-run Theos `Makefile` + `control`; build:  make
#   * XCODE — configure with `-G Xcode` + the leetal/ios-cmake toolchain to build a
#             native .app target from the per-directory source tree.
# Choose with -DBUILD_BACKEND=THEOS|XCODE|AUTO (default AUTO: Theos if present).
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
set(BUILD_BACKEND "AUTO" CACHE STRING "Build backend: AUTO | THEOS | XCODE")
set_property(CACHE BUILD_BACKEND PROPERTY STRINGS AUTO THEOS XCODE)

set(IOS_ARCHS "armv7 armv7s arm64 arm64e" CACHE STRING "Space-separated architecture slices")
set(IOS_DEPLOYMENT_TARGET "5.1.1" CACHE STRING "Minimum iOS version (fat-binary floor)")
if(DEFINED DEPLOYMENT_TARGET)                 # leetal/ios-cmake spelling
    set(IOS_DEPLOYMENT_TARGET "${DEPLOYMENT_TARGET}")
endif()
set(IOS_SDK_VERSION "latest" CACHE STRING "SDK version for the Theos TARGET (e.g. 12.2 or 'latest')")

set(THEOS      "$ENV{THEOS}" CACHE PATH "Path to a Theos install (blank = autodetect)")
set(XCODE_PATH ""            CACHE PATH "Path to Xcode developer dir (blank = xcode-select)")

set(APP_BUNDLE_ID    "jp.co.konami.popnrhythmin" CACHE STRING "CFBundleIdentifier")
set(APP_DISPLAY_NAME "pop'n rhythmin"            CACHE STRING "CFBundleDisplayName")
set(APP_VERSION      "2.0.3"                      CACHE STRING "CFBundleShortVersionString")
set(APP_BUILD        "2.0.3"                      CACHE STRING "CFBundleVersion")
set(RESOURCES_DIR    "" CACHE PATH "Directory of the ORIGINAL extracted .app whose resources "
                                   "(images, rhythmin.lv, .acv/.orb/.idx, fonts, ...) are copied "
                                   "verbatim into the built bundle. Leave empty to build code only.")

# ---------------------------------------------------------------------------
# Toolchain discovery
# ---------------------------------------------------------------------------
if(NOT THEOS)
    foreach(_cand "$ENV{HOME}/theos" "/opt/theos" "/var/theos" "/usr/local/theos")
        if(EXISTS "${_cand}/makefiles/common.mk")
            set(THEOS "${_cand}")
            break()
        endif()
    endforeach()
endif()
if(THEOS AND EXISTS "${THEOS}/makefiles/common.mk")
    set(THEOS_FOUND TRUE)
    message(STATUS "PopnRhythmin: found Theos at ${THEOS}")
else()
    set(THEOS_FOUND FALSE)
endif()

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
    set(XCODE_FOUND TRUE)
    message(STATUS "PopnRhythmin: found Xcode/developer dir at ${XCODE_PATH}")
else()
    set(XCODE_FOUND FALSE)
endif()

if(BUILD_BACKEND STREQUAL "AUTO")
    if(THEOS_FOUND)
        set(BUILD_BACKEND "THEOS")
    else()
        set(BUILD_BACKEND "XCODE")
    endif()
endif()
message(STATUS "PopnRhythmin: backend=${BUILD_BACKEND} archs='${IOS_ARCHS}' iOS>=${IOS_DEPLOYMENT_TARGET}")

# Frameworks actually #import-ed across the sources (shared by both backends).
set(SYS_FRAMEWORKS
    UIKit Foundation CoreGraphics QuartzCore CoreText
    OpenGLES AudioToolbox AVFoundation
    CoreData StoreKit Social
    Security SystemConfiguration CFNetwork)

# =========================================================================
# BACKEND: THEOS — generate a Theos Makefile + control from templates, then stop.
# Theos globs its own sources, so the per-directory CMakeLists are not needed here.
# =========================================================================
if(BUILD_BACKEND STREQUAL "THEOS")
    if(NOT THEOS_FOUND)
        message(FATAL_ERROR "BUILD_BACKEND=THEOS but no Theos found. Set -DTHEOS=/path/to/theos.")
    endif()
    set(THEOS_TARGET "iphone:clang:${IOS_SDK_VERSION}:${IOS_DEPLOYMENT_TARGET}")
    set(THEOS_ARCHS  "${IOS_ARCHS}")
    set(THEOS_FRAMEWORKS "UIKit Foundation CoreGraphics QuartzCore CoreText OpenGLES AudioToolbox AVFoundation CoreData StoreKit Social")
    set(THEOS_LDFLAGS    "-framework Security -framework SystemConfiguration -framework CFNetwork -lz")

    configure_file("${CMAKE_CURRENT_SOURCE_DIR}/theos/Makefile.in"
                   "${CMAKE_CURRENT_SOURCE_DIR}/Makefile" @ONLY)
    configure_file("${CMAKE_CURRENT_SOURCE_DIR}/theos/control.in"
                   "${CMAKE_CURRENT_SOURCE_DIR}/control" @ONLY)
    configure_file("${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
                   "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Info.plist" @ONLY)
    message(STATUS "PopnRhythmin: wrote Theos Makefile + control + Resources/Info.plist.")
    message(STATUS "  Build:   THEOS=${THEOS} make        Package: THEOS=${THEOS} make package")
    if(NOT (RESOURCES_DIR AND EXISTS "${RESOURCES_DIR}"))
        message(WARNING "  RESOURCES_DIR not set: populate ./Resources/ from the original .app first.")
    else()
        message(STATUS "  Copy assets: rsync -a --exclude PopnRhythmin --exclude _CodeSignature --exclude Info.plist \"${RESOURCES_DIR}/\" Resources/")
    endif()
    return()
endif()

# =========================================================================
# BACKEND: XCODE / native — real .app target, fed by per-directory CMakeLists.
# =========================================================================
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

add_subdirectory(Project)

target_compile_options(popnrhythmin PRIVATE
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-fno-objc-arc>
    -fobjc-exceptions -Wno-deprecated-declarations)

set_target_properties(popnrhythmin PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${INFO_PLIST}"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${APP_BUNDLE_ID}"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "${IOS_DEPLOYMENT_TARGET}"
    XCODE_ATTRIBUTE_ARCHS "${IOS_ARCHS}"
    XCODE_ATTRIBUTE_VALID_ARCHS "${IOS_ARCHS}"
    XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH "NO"
    XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
    XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "NO"
    XCODE_ATTRIBUTE_GCC_C_LANGUAGE_STANDARD "gnu11"
    XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD "gnu++14"
    XCODE_ATTRIBUTE_CLANG_CXX_LIBRARY "libc++"
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
