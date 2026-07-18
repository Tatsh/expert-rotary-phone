THEOS_MAKEFILE_DIR := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))
PROJECT_ROOT       := $(patsubst %/,%,$(dir $(THEOS_MAKEFILE_DIR)))

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

export ARCHS  = armv7 armv7s arm64 arm64e
export TARGET = iphone:clang:latest:5.1.1

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = PopnRhythmin

PopnRhythmin_FILES = $(shell find $(PROJECT_ROOT)/Project \
                         \( -name '*.m' -o -name '*.mm' -o -name '*.c' -o -name '*.cpp' \)) \
                     $(PROJECT_ROOT)/3rdparty/ziparchive/UnZipArchive.mm \
                     $(PROJECT_ROOT)/3rdparty/ziparchive/minizip/ioapi.c \
                     $(PROJECT_ROOT)/3rdparty/ziparchive/minizip/unzip.c \
                     $(PROJECT_ROOT)/3rdparty/ziparchive/minizip/zip.c

PopnRhythmin_WARNINGS = -Wall -Wextra -Wshadow -Wcomma -Wnewline-eof -Wpointer-arith \
                        -Wimplicit-fallthrough -Wunreachable-code -Wconditional-uninitialized \
                        -Winfinite-recursion \
                        -Wundeclared-selector -Wblock-capture-autoreleasing \
                        -Wobjc-literal-conversion -Wduplicate-method-match -Wimplicit-retain-self
PopnRhythmin_CFLAGS  = -std=gnu2x -ftrivial-auto-var-init=zero -fobjc-arc -fobjc-exceptions \
                       -DGLES_SILENCE_DEPRECATION \
                       $(PopnRhythmin_WARNINGS) \
                       -I$(PROJECT_ROOT)/Project \
                       $(addprefix -I,$(shell find $(PROJECT_ROOT)/Project -type d)) \
                       -I$(SUGO_GEN_DIR) \
                       -I$(PROJECT_ROOT)/3rdparty/ziparchive \
                       -I$(PROJECT_ROOT)/3rdparty/ziparchive/minizip
PopnRhythmin_CCFLAGS = -std=gnu++2b -stdlib=libc++ -fno-char8_t \
                       -D_LIBCPP_ENABLE_ASSERTIONS=1 \
                       -Woverloaded-virtual -Wnon-virtual-dtor \
                       -Wdelete-non-abstract-non-virtual-dtor -Wrange-loop-analysis -Wextra-semi
$(PROJECT_ROOT)/3rdparty/ziparchive/minizip/ioapi.c_CFLAGS = -std=gnu17 -w
$(PROJECT_ROOT)/3rdparty/ziparchive/minizip/unzip.c_CFLAGS = -std=gnu17 -w
$(PROJECT_ROOT)/3rdparty/ziparchive/minizip/zip.c_CFLAGS = -std=gnu17 -w

PopnRhythmin_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore CoreText OpenGLES \
                          AudioToolbox AVFoundation CoreData StoreKit Social \
                          GameKit AdSupport CoreLocation MapKit WebKit UserNotifications
PopnRhythmin_LDFLAGS    = -framework Security -framework SystemConfiguration \
                          -framework CFNetwork -lz

include $(THEOS)/makefiles/application.mk

# kate: hl Makefile;
