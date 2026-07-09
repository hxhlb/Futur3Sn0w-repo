THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = CustHomePrefs

CustHomePrefs_FILES = CHPRootListController.m
CustHomePrefs_FRAMEWORKS = UIKit
CustHomePrefs_PRIVATE_FRAMEWORKS = Preferences
CustHomePrefs_INSTALL_PATH = /Library/PreferenceBundles
CustHomePrefs_CFLAGS = -fobjc-arc
CustHomePrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk

after-CustHomePrefs-stage::
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"$(ECHO_END)
	$(ECHO_NOTHING)cp "Resources/entry.plist" "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/CustHomePrefs.plist"$(ECHO_END)
	$(ECHO_NOTHING)chmod 755 "$(THEOS_STAGING_DIR)/Library/PreferenceBundles/CustHomePrefs.bundle/CustHomePrefs"$(ECHO_END)
