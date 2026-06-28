export TARGET ?= iphone:clang:16.5:16.0
export ARCHS ?= arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CustHome

CustHome_FILES = Hooks/S15HomeEditMenu.x
CustHome_CFLAGS = -fobjc-arc
CustHome_FRAMEWORKS = UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
