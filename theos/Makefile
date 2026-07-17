# theos/Makefile — FIXED, hand-maintained Theos application project for pop'n rhythmin.
#
# This is the ONLY supported Theos entry point (CMake no longer generates one). Build it
# directly — no configure step:
#
#     make -C theos                 # build PopnRhythmin.app
#     make -C theos package         # build a .deb
#     make -C theos THEOS=/path     # if $THEOS is not already in the environment
#
# The reconstructed sources live one level up (../Project). This Makefile lives in ./theos/
# so it can be tracked in git (the repo root Makefile is .gitignored as a build artifact);
# it anchors every path back to the repo root via its own location, so it builds correctly
# no matter the current working directory.

# Absolute path to the repo root (the directory that contains this theos/ folder).
THEOS_MAKEFILE_DIR := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))
PROJECT_ROOT       := $(patsubst %/,%,$(dir $(THEOS_MAKEFILE_DIR)))

# ---------------------------------------------------------------------------
# Sugoroku board character-message dialogue (mirrors the CMake configure step).
# TreasureMap.mm #includes sugoroku_chara_msg.generated.inc; the ~330 board strings are
# copyrighted game content and are NOT in the tree. Generate the include here, at parse
# time, so the compile always finds it. Point at an owned binary to embed the real text:
#     make -C theos POPNRHYTHMIN_BINARY=/path/to/Payload/PopnRhythmin.app/PopnRhythmin
# With no binary set, empty tables are emitted (board messages render blank).
# ---------------------------------------------------------------------------
SUGO_GEN_DIR := $(THEOS_MAKEFILE_DIR)/generated
SUGO_GEN_INC := $(SUGO_GEN_DIR)/sugoroku_chara_msg.generated.inc
SUGO_SCRIPT  := $(PROJECT_ROOT)/tools/extract_sugoroku_dialogue.py
PYTHON3      ?= python3
_sugo := $(shell mkdir -p "$(SUGO_GEN_DIR)"; \
    if [ -n "$(POPNRHYTHMIN_BINARY)" ] && [ -f "$(POPNRHYTHMIN_BINARY)" ]; then \
        "$(PYTHON3)" "$(SUGO_SCRIPT)" --format c "$(POPNRHYTHMIN_BINARY)" "$(SUGO_GEN_INC)" \
            || "$(PYTHON3)" "$(SUGO_SCRIPT)" --emit-empty "$(SUGO_GEN_INC)"; \
    elif [ ! -f "$(SUGO_GEN_INC)" ]; then \
        "$(PYTHON3)" "$(SUGO_SCRIPT)" --emit-empty "$(SUGO_GEN_INC)"; \
    fi)

# Fat binary: legacy 32-bit slices + modern 64-bit ones (so it runs on iOS 11+).
# Drop slices your installed Xcode/SDK cannot produce, e.g. ARCHS = arm64.
export ARCHS  = armv7 armv7s arm64 arm64e
export TARGET = iphone:clang:latest:5.1.1

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = PopnRhythmin

# All reconstructed sources (under Project/) plus the vendored ZipArchive/minizip (3rdparty/):
# the UnZipArchive class the music-data loaders use for .zip chart extraction.
PopnRhythmin_FILES = $(shell find $(PROJECT_ROOT)/Project \
                         \( -name '*.m' -o -name '*.mm' -o -name '*.c' -o -name '*.cpp' \)) \
                     $(PROJECT_ROOT)/3rdparty/ziparchive/UnZipArchive.mm \
                     $(PROJECT_ROOT)/3rdparty/ziparchive/minizip/ioapi.c \
                     $(PROJECT_ROOT)/3rdparty/ziparchive/minizip/unzip.c \
                     $(PROJECT_ROOT)/3rdparty/ziparchive/minizip/zip.c

# ARC (the reconstructed sources use ARC — __bridge casts + ARC-synthesized dealloc —
# exactly as the CMake/Xcode build does); every Project subdir on -I, plus the generated
# sugoroku dialogue include dir (see tools/extract_sugoroku_dialogue.py).
PopnRhythmin_CFLAGS  = -std=gnu23 -fobjc-arc -fobjc-exceptions -DGLES_SILENCE_DEPRECATION \
                       -I$(PROJECT_ROOT)/Project \
                       $(addprefix -I,$(shell find $(PROJECT_ROOT)/Project -type d)) \
                       -I$(SUGO_GEN_DIR) \
                       -I$(PROJECT_ROOT)/3rdparty/ziparchive \
                       -I$(PROJECT_ROOT)/3rdparty/ziparchive/minizip
PopnRhythmin_CCFLAGS = -std=gnu++23 -stdlib=libc++
# minizip is vendored upstream C we do not patch; silence its extraneous
# parentheses-equality warnings there without touching the third-party source.
$(PROJECT_ROOT)/3rdparty/ziparchive/minizip/ioapi.c_CFLAGS = -Wno-parentheses-equality
$(PROJECT_ROOT)/3rdparty/ziparchive/minizip/unzip.c_CFLAGS = -Wno-parentheses-equality
$(PROJECT_ROOT)/3rdparty/ziparchive/minizip/zip.c_CFLAGS = -Wno-parentheses-equality

PopnRhythmin_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore CoreText OpenGLES \
                          AudioToolbox AVFoundation CoreData StoreKit Social \
                          GameKit AdSupport CoreLocation MapKit WebKit UserNotifications
PopnRhythmin_LDFLAGS    = -framework Security -framework SystemConfiguration \
                          -framework CFNetwork -lz

include $(THEOS)/makefiles/application.mk

# kate: hl Makefile;
