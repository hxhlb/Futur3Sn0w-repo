ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ReRoadRunnerPrefs
ReRoadRunnerPrefs_FILES = RRRootListController.m $(wildcard *.xm) $(wildcard *.m) ../SettingsKeys.m
ReRoadRunnerPrefs_INSTALL_PATH = /Library/PreferenceBundles
ReRoadRunnerPrefs_FRAMEWORKS = UIKit
ReRoadRunnerPrefs_PRIVATE_FRAMEWORKS = Preferences
ReRoadRunnerPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
ReRoadRunnerPrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk

after-ReRoadRunnerPrefs-stage::
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"$(ECHO_END)
	$(ECHO_NOTHING)cp "entry.plist" "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/ReRoadRunnerPrefs.plist"$(ECHO_END)
