ARCHS = arm64
TARGET = iphone:clang:16.5:11.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SevenEleven

SevenEleven_FILES = Tweak.xm
SevenEleven_FRAMEWORKS = UIKit QuartzCore
SevenEleven_CFLAGS = -fobjc-arc

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
