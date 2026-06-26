ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ReSettingsPrefs

ReSettingsPrefs_FILES = SCRootListController.m ../SCCommon.m
ReSettingsPrefs_FRAMEWORKS = UIKit
ReSettingsPrefs_PRIVATE_FRAMEWORKS = Preferences
ReSettingsPrefs_INSTALL_PATH = /Library/PreferenceBundles
ReSettingsPrefs_CFLAGS = -fobjc-arc
ReSettingsPrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk

after-ReSettingsPrefs-stage::
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"$(ECHO_END)
	$(ECHO_NOTHING)cp "Resources/ReSettingsPrefs.plist" "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/ReSettingsPrefs.plist"$(ECHO_END)
