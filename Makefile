.PHONY: build release clean version

VERSION := $(shell git describe --tags --dirty 2>/dev/null | sed 's/^v//' || echo "dev")
VERSION_FILE := Sources/web-receipts/Version.swift

build: version
	swift build

release: version
	swift build -c release --arch arm64

clean:
	swift package clean
	rm -f $(VERSION_FILE)

version:
	@echo "// Auto-generated - do not edit" > $(VERSION_FILE)
	@echo "let appVersion = \"$(VERSION)\"" >> $(VERSION_FILE)
	@echo "Version: $(VERSION)"
