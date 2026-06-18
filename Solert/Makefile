ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard Preferences MobileSafari MobileSlideShow Shortcuts

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Solert

Solert_FILES = Tweak.xm
Solert_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "sbreload"
