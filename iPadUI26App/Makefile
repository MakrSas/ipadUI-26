TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = iPadUI26

iPadUI26_FILES = main.m
iPadUI26_FRAMEWORKS = UIKit
iPadUI26_PRIVATE_FRAMEWORKS = Preferences
iPadUI26_CFLAGS = -fobjc-arc
iPadUI26_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
