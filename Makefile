# Convenience wrappers around XcodeGen and xcodebuild.

DERIVED_DATA := .build/DerivedData
APP := $(DERIVED_DATA)/Build/Products/Debug/stitsch.app
RELEASE_APP := $(DERIVED_DATA)/Build/Products/Release/stitsch.app
INSTALL_DIR := /Applications

PROJECT := Stitch.xcodeproj
SCHEME := Stitch
APP_ID := com.defik74.stitch
TEAM_ID := B592D69P29

ARCHIVE_MACOS := .build/Stitch-macOS.xcarchive
ARCHIVE_IOS := .build/Stitch-iOS.xcarchive
EXPORT_DIR := .build/export

# Local builds can opt out of signing entirely, which is what CI and machines without the
# distribution certificate want: `make build SIGNING=0`.
SIGNING ?= 1
ifeq ($(SIGNING),0)
SIGNING_FLAGS := CODE_SIGNING_ALLOWED=NO
else
SIGNING_FLAGS := -allowProvisioningUpdates
endif

# xcodebuild and simctl need the full Xcode toolchain. When the Command Line Tools are
# selected, point at Xcode.app instead so `make` works without sudo xcode-select.
ifeq ($(shell xcode-select -p 2>/dev/null),/Library/Developer/CommandLineTools)
export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer
endif

.PHONY: all generate build test run install clean \
	archive-macos archive-ios export-macos export-ios upload-macos upload-ios publish

all: build

## Regenerate Stitch.xcodeproj from project.yml
generate:
	xcodegen generate

## Build the macOS app
build: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		-configuration Debug \
		-derivedDataPath $(DERIVED_DATA) \
		$(SIGNING_FLAGS) \
		build

## Run the StitchKit unit tests
test:
	cd StitchKit && swift test

## Build and launch the macOS app
run: build
	open $(APP)

## Build the Release app and install it into /Applications
install: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		-configuration Release \
		-derivedDataPath $(DERIVED_DATA) \
		$(SIGNING_FLAGS) \
		build
	rm -rf $(INSTALL_DIR)/stitsch.app
	ditto $(RELEASE_APP) $(INSTALL_DIR)/stitsch.app
	open $(INSTALL_DIR)/stitsch.app

## Archive the macOS app for distribution
archive-macos: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'generic/platform=macOS' \
		-configuration Release \
		-archivePath $(ARCHIVE_MACOS) \
		-allowProvisioningUpdates \
		archive

## Archive the iOS app for distribution
archive-ios: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'generic/platform=iOS' \
		-configuration Release \
		-archivePath $(ARCHIVE_IOS) \
		-allowProvisioningUpdates \
		archive

## Export the macOS archive as a signed App Store package
export-macos: archive-macos
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_MACOS) \
		-exportOptionsPlist AppStore/ExportOptions.plist \
		-exportPath $(EXPORT_DIR)/macOS \
		-allowProvisioningUpdates

## Export the iOS archive as a signed App Store package
export-ios: archive-ios
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_IOS) \
		-exportOptionsPlist AppStore/ExportOptions.plist \
		-exportPath $(EXPORT_DIR)/iOS \
		-allowProvisioningUpdates

## Upload the macOS build to App Store Connect
upload-macos: archive-macos
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_MACOS) \
		-exportOptionsPlist AppStore/UploadOptions.plist \
		-exportPath $(EXPORT_DIR)/upload-macOS \
		-allowProvisioningUpdates

## Upload the iOS build to App Store Connect
upload-ios: archive-ios
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_IOS) \
		-exportOptionsPlist AppStore/UploadOptions.plist \
		-exportPath $(EXPORT_DIR)/upload-iOS \
		-allowProvisioningUpdates

## Upload both platforms
publish: upload-macos upload-ios

clean:
	rm -rf $(PROJECT) Stitch/Resources/Info.plist $(DERIVED_DATA) $(EXPORT_DIR) \
		$(ARCHIVE_MACOS) $(ARCHIVE_IOS)
	cd StitchKit && swift package clean

