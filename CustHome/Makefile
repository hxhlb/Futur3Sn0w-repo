export TARGET ?= iphone:clang:16.5:16.0
export ARCHS ?= arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

INSTALL_TARGET_PROCESSES = SpringBoard Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CustHome
# CustHomePrefs is pulled from the build for now -- it's not wired into
# anything the customize sheet itself needs yet, and was showing as a blank
# pane in Settings. Source is left in CustHomePrefs/ to pick back up later.
# SUBPROJECTS += CustHomePrefs

CustHome_FILES = Hooks/S15HomeEditMenu.x
CustHome_CFLAGS = -fobjc-arc
CustHome_FRAMEWORKS = UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

before-package::
	find $(THEOS_STAGING_DIR) -type d -exec chmod 755 {} +
	chmod -R a+rX $(THEOS_STAGING_DIR)
