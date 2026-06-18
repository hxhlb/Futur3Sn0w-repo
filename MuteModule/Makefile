ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MuteModule

MuteModule_FILES = Tweak.xm
MuteModule_FRAMEWORKS = Foundation
MuteModule_LIBRARIES = substrate
MuteModule_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "sbreload"
