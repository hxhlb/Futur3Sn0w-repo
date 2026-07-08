TARGET := iphone:clang:16.5:14.0
THEOS_PACKAGE_SCHEME = rootless
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DockLibrary

DockLibrary_FILES = Tweak.x
DockLibrary_CFLAGS = -fobjc-arc
DockLibrary_FRAMEWORKS = UIKit

include $(THEOS)/makefiles/tweak.mk

before-package::
	find $(THEOS_STAGING_DIR) -type d -exec chmod 755 {} +
	chmod -R a+rX $(THEOS_STAGING_DIR)

SUBPROJECTS += Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
