export ARCHS = arm64 arm64e
export THEOS_PACKAGE_SCHEME = rootless
export TARGET = iphone:clang:16.5:15.0

INSTALL_TARGET_PROCESSES = SpringBoard

SUBPROJECTS += Tweak Preferences

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
