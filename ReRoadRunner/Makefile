ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ReRoadRunner
ReRoadRunner_FILES = $(wildcard *.xm) SettingsKeys.m
ReRoadRunner_PRIVATE_FRAMEWORKS = MediaRemote
ReRoadRunner_CFLAGS = -fobjc-arc
INSTALL_TARGET_PROCESSES = SpringBoard runningboardd TextInput Preferences

include $(THEOS_MAKE_PATH)/tweak.mk


ifdef SB_ONLY
after-install::
	install.exec "killall -9 SpringBoard"
else ifdef PREFS_ONLY
after-install::
		install.exec "killall -9 Preferences"
else ifdef RB_ONLY
after-install::
		install.exec "killall -9 runningboardd"
else ifdef APPS_ONLY
after-install::
		install.exec "killall -9 Spotify"
else
after-install::
		install.exec "sbreload"
endif

SUBPROJECTS += preferences
include $(THEOS_MAKE_PATH)/aggregate.mk
