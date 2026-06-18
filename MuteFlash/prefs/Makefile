ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MuteFlashPrefs

MuteFlashPrefs_FILES = MFPRootListController.m
MuteFlashPrefs_FRAMEWORKS = UIKit
MuteFlashPrefs_PRIVATE_FRAMEWORKS = Preferences
MuteFlashPrefs_INSTALL_PATH = /Library/PreferenceBundles
MuteFlashPrefs_CFLAGS = -fobjc-arc
MuteFlashPrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk

after-MuteFlashPrefs-stage::
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"$(ECHO_END)
	$(ECHO_NOTHING)cp "Resources/MuteFlashPrefs.plist" "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/MuteFlashPrefs.plist"$(ECHO_END)
