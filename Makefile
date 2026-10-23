TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard
THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = iPadUI26

iPadUI26_FILES = $(wildcard Sources/*.m)
iPadUI26_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
iPadUI26_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += iPadUI26Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
