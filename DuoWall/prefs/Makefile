ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = DuoWallPrefs

DuoWallPrefs_FILES = DWRootListController.m
DuoWallPrefs_FRAMEWORKS = UIKit PhotosUI
DuoWallPrefs_PRIVATE_FRAMEWORKS = Preferences
DuoWallPrefs_INSTALL_PATH = /Library/PreferenceBundles
DuoWallPrefs_CFLAGS = -fobjc-arc
DuoWallPrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk

after-DuoWallPrefs-stage::
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"$(ECHO_END)
	$(ECHO_NOTHING)cp "Resources/DuoWallPrefs.plist" "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/DuoWallPrefs.plist"$(ECHO_END)
