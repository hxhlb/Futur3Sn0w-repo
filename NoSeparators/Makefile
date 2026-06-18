ARCHS = arm64
TARGET = iphone:clang:16.5:11.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NoSeparators

NoSeparators_FILES = Tweak.xm
NoSeparators_FRAMEWORKS = UIKit CoreFoundation
NoSeparators_CFLAGS = -fobjc-arc

INSTALL_TARGET_PROCESSES = SpringBoard Preferences

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs

include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"
