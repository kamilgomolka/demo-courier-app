PROJECT := CourierApp.xcodeproj
SCHEME := CourierApp
PACKAGE_DIRECTORY := CourierModules
PACKAGE_SCHEME := CourierModules
SIMULATOR ?= iPhone 17 Pro
OS ?= 26.5
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR),OS=$(OS)
RESULT_BUNDLE := $(CURDIR)/TestResults.xcresult
PACKAGE_RESULT_BUNDLE := $(CURDIR)/PackageTestResults.xcresult
STRICT_WARNINGS := SWIFT_SUPPRESS_WARNINGS=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
SWIFT_SOURCES := CourierApp CourierAppUITests CourierModules

.PHONY: build test test-package test-app destinations format lint clean

build:
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' CODE_SIGNING_ALLOWED=NO $(STRICT_WARNINGS)

test: test-package test-app

test-package:
	rm -rf $(PACKAGE_RESULT_BUNDLE)
	cd $(PACKAGE_DIRECTORY) && xcodebuild test -scheme $(PACKAGE_SCHEME) \
		-destination '$(DESTINATION)' -resultBundlePath $(PACKAGE_RESULT_BUNDLE) $(STRICT_WARNINGS)

test-app:
	rm -rf $(RESULT_BUNDLE)
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' -resultBundlePath $(RESULT_BUNDLE) \
		CODE_SIGNING_ALLOWED=NO $(STRICT_WARNINGS)

destinations:
	xcodebuild -showdestinations -project $(PROJECT) -scheme $(SCHEME)

format:
	xcrun swift-format format --in-place --recursive --parallel $(SWIFT_SOURCES)

lint:
	xcrun swift-format lint --strict --recursive --parallel $(SWIFT_SOURCES)

clean:
	rm -rf $(RESULT_BUNDLE) $(PACKAGE_RESULT_BUNDLE)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME)
