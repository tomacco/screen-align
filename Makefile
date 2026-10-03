# Command Line Tools ship the swift-testing macro plugin outside the default search path.
TEST_FLAGS := $(if $(findstring CommandLineTools,$(shell xcode-select -p)),-Xswiftc -plugin-path -Xswiftc $(shell xcode-select -p)/usr/lib/swift/host/plugins/testing,)

.PHONY: build test app install run clean

build:
	swift build

test:
	swift test $(TEST_FLAGS)

app:
	scripts/build-app.sh

install:
	scripts/build-app.sh --install

run: install
	open ~/Applications/ScreenAlign.app

clean:
	rm -rf .build build
