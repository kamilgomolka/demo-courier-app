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
XCODEBUILD_QUIET ?=
SUMMARIZE_FAILURES := xcrun xcresulttool get test-results summary --compact --path

package_test = cd $(PACKAGE_DIRECTORY) && xcodebuild test -scheme $(PACKAGE_SCHEME) \
	-destination '$(DESTINATION)' -resultBundlePath $(PACKAGE_RESULT_BUNDLE) $(XCODEBUILD_QUIET) $(1) $(STRICT_WARNINGS) \
	|| { $(SUMMARIZE_FAILURES) $(PACKAGE_RESULT_BUNDLE) \
	| jq -c '{failedTests, passedTests, testFailures: [.testFailures[] | {testIdentifierString, failureText}]}'; exit 1; }

.PHONY: build build-release check test test-package test-module test-app destinations format lint clean

build:
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' $(XCODEBUILD_QUIET) CODE_SIGNING_ALLOWED=NO $(STRICT_WARNINGS)

build-release:
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-destination '$(DESTINATION)' $(XCODEBUILD_QUIET) CODE_SIGNING_ALLOWED=NO $(STRICT_WARNINGS)

check:
	$(MAKE) XCODEBUILD_QUIET=-quiet lint build build-release test-package

test: test-package test-app

test-package:
	rm -rf $(PACKAGE_RESULT_BUNDLE)
	$(call package_test)

test-module:
	$(if $(MODULE),,$(error MODULE is required, e.g. make test-module MODULE=SyncEngineTests))
	rm -rf $(PACKAGE_RESULT_BUNDLE)
	$(call package_test,-only-testing:$(MODULE))

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
