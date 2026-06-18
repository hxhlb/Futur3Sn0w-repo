ARCHS = arm64

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = NoSeparatorsPrefs

NoSeparatorsPrefs_FILES = NSPRootListController.m
NoSeparatorsPrefs_FRAMEWORKS = UIKit
NoSeparatorsPrefs_PRIVATE_FRAMEWORKS = Preferences
NoSeparatorsPrefs_INSTALL_PATH = /Library/PreferenceBundles
NoSeparatorsPrefs_CFLAGS = -fobjc-arc
NoSeparatorsPrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk

after-NoSeparatorsPrefs-stage::
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"$(ECHO_END)
	$(ECHO_NOTHING)cp "Resources/NoSeparatorsPrefs.plist" "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/NoSeparatorsPrefs.plist"$(ECHO_END)
