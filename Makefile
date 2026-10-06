# Convenience wrappers around XcodeGen and xcodebuild.

DERIVED_DATA := .build/DerivedData
APP := $(DERIVED_DATA)/Build/Products/Debug/Stitch.app

# xcodebuild and simctl need the full Xcode toolchain. When the Command Line Tools are
# selected, point at Xcode.app instead so `make` works without sudo xcode-select.
ifeq ($(shell xcode-select -p 2>/dev/null),/Library/Developer/CommandLineTools)
export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer
endif

.PHONY: all generate build test run clean

all: build

## Regenerate Stitch.xcodeproj from project.yml
generate:
	xcodegen generate

## Build the macOS app
build: generate
	xcodebuild \
		-project Stitch.xcodeproj \
		-scheme Stitch \
		-destination 'platform=macOS' \
		-configuration Debug \
		-derivedDataPath $(DERIVED_DATA) \
		build

## Run the StitchKit unit tests
test:
	cd StitchKit && swift test

## Build and launch the macOS app
run: build
	open $(APP)

clean:
	rm -rf Stitch.xcodeproj Stitch/Resources/Info.plist $(DERIVED_DATA)
	cd StitchKit && swift package clean
