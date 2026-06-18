ARCHS = arm64
TARGET = iphone:clang:16.5:11.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CenterLastRow

CenterLastRow_FILES = Tweak.xm
CenterLastRow_FRAMEWORKS = UIKit
CenterLastRow_CFLAGS = -fobjc-arc

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
