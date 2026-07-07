ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SevenUpPrefs

SevenUpPrefs_FILES = SUPRootListController.m
SevenUpPrefs_FRAMEWORKS = UIKit
SevenUpPrefs_PRIVATE_FRAMEWORKS = Preferences
SevenUpPrefs_INSTALL_PATH = /Library/PreferenceBundles
SevenUpPrefs_CFLAGS = -fobjc-arc
SevenUpPrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk

after-SevenUpPrefs-stage::
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"$(ECHO_END)
	$(ECHO_NOTHING)cp "Resources/SevenUpPrefs.plist" "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SevenUpPrefs.plist"$(ECHO_END)
