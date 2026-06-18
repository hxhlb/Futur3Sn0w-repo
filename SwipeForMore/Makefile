TARGET = iphone:clang:latest:7.0
ARCHS = armv7
PACKAGE_VERSION = 1.2.5+ios7.12
INSTALL_TARGET_PROCESSES = Cydia

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SwipeForMore
$(TWEAK_NAME)_FILES = SwipeActionController.m Tweak.xm
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -marm
$(TWEAK_NAME)_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
