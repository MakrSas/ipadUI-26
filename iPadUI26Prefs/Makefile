TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = iPadUI26Prefs

iPadUI26Prefs_FILES = $(wildcard *.m) ../Sources/PUPrefs.m
iPadUI26Prefs_FRAMEWORKS = UIKit
iPadUI26Prefs_PRIVATE_FRAMEWORKS = Preferences
iPadUI26Prefs_INSTALL_PATH = /Library/PreferenceBundles
iPadUI26Prefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/bundle.mk
