ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BattFXPrefs

BattFXPrefs_FILES = BFXRootListController.m
BattFXPrefs_FRAMEWORKS = UIKit
BattFXPrefs_PRIVATE_FRAMEWORKS = Preferences
BattFXPrefs_INSTALL_PATH = /Library/PreferenceBundles
BattFXPrefs_CFLAGS = -fobjc-arc
BattFXPrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk

after-BattFXPrefs-stage::
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"$(ECHO_END)
	$(ECHO_NOTHING)cp "Resources/BattFXPrefs.plist" "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/BattFXPrefs.plist"$(ECHO_END)
