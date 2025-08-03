# Makefile for gotty

BINARY_NAME := gotty
OUTPUT_DIR := builds
VERSION := $(shell git describe --tags 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "0.0.0")
COMMIT := $(shell git rev-parse HEAD 2>/dev/null || echo "unknown")

# Build flags
LDFLAGS := -X main.Version=$(VERSION) -X main.Commit=$(COMMIT) -s -w
GO_BUILD_CMD := CGO_ENABLED=0 go build -ldflags "$(LDFLAGS)"

# Default target
.PHONY: all
all: build

# ------------------------------------------------------------------------------
# Development & Local Build
# ------------------------------------------------------------------------------

.PHONY: build
build: assets
	$(GO_BUILD_CMD) -o $(BINARY_NAME)

.PHONY: build-binary
build-binary:
	$(GO_BUILD_CMD) -o $(BINARY_NAME)

.PHONY: install
install: assets
	CGO_ENABLED=0 go install -ldflags "$(LDFLAGS)"

.PHONY: test
test:
	go test -v ./...

.PHONY: clean
clean:
	rm -rf $(OUTPUT_DIR)
	rm -f $(BINARY_NAME)
	rm -rf bindata/static
	rm -rf js/dist js/node_modules

# ------------------------------------------------------------------------------
# Frontend & Assets
# ------------------------------------------------------------------------------

.PHONY: assets
assets: frontend-install frontend-build copy-assets

.PHONY: frontend-install
frontend-install:
	cd js && bun install

.PHONY: frontend-build
frontend-build:
	cd js && bunx webpack --mode=production

.PHONY: copy-assets
copy-assets:
	mkdir -p bindata/static/css bindata/static/js
	cp js/dist/gotty.js bindata/static/js/
	cp js/dist/gotty.js.map bindata/static/js/
	cp resources/favicon.ico bindata/static/
	cp resources/icon.svg bindata/static/
	cp resources/icon_192.png bindata/static/
	cp resources/index.html bindata/static/
	cp resources/manifest.json bindata/static/
	cp resources/index.css bindata/static/css/
	cp resources/xterm_customize.css bindata/static/css/
	# Ensure xterm.css is available (installed via frontend-install)
	cp js/node_modules/@xterm/xterm/css/xterm.css bindata/static/css/

# ------------------------------------------------------------------------------
# Cross Compilation (Linux, Mac, Windows)
# ------------------------------------------------------------------------------

.PHONY: build-all
build-all: build-linux build-mac build-win

.PHONY: build-linux
build-linux: assets
	@echo "Building for Linux..."
	mkdir -p $(OUTPUT_DIR)/linux
	GOOS=linux GOARCH=amd64 $(GO_BUILD_CMD) -o $(OUTPUT_DIR)/linux/$(BINARY_NAME)_linux_amd64
	GOOS=linux GOARCH=arm64 $(GO_BUILD_CMD) -o $(OUTPUT_DIR)/linux/$(BINARY_NAME)_linux_arm64

.PHONY: build-mac
build-mac: assets
	@echo "Building for macOS (Darwin)..."
	mkdir -p $(OUTPUT_DIR)/mac
	GOOS=darwin GOARCH=amd64 $(GO_BUILD_CMD) -o $(OUTPUT_DIR)/mac/$(BINARY_NAME)_darwin_amd64
	GOOS=darwin GOARCH=arm64 $(GO_BUILD_CMD) -o $(OUTPUT_DIR)/mac/$(BINARY_NAME)_darwin_arm64

.PHONY: build-win
build-win: assets
	@echo "Building for Windows..."
	mkdir -p $(OUTPUT_DIR)/windows
	GOOS=windows GOARCH=amd64 $(GO_BUILD_CMD) -o $(OUTPUT_DIR)/windows/$(BINARY_NAME)_windows_amd64.exe

# ------------------------------------------------------------------------------
# Packaging (for Release)
# ------------------------------------------------------------------------------

DIST_DIR := $(OUTPUT_DIR)/dist

.PHONY: package
package: build-all
	mkdir -p $(DIST_DIR)
	# Linux
	tar -czf $(DIST_DIR)/$(BINARY_NAME)_linux_amd64.tar.gz -C $(OUTPUT_DIR)/linux $(BINARY_NAME)_linux_amd64
	tar -czf $(DIST_DIR)/$(BINARY_NAME)_linux_arm64.tar.gz -C $(OUTPUT_DIR)/linux $(BINARY_NAME)_linux_arm64
	# macOS
	tar -czf $(DIST_DIR)/$(BINARY_NAME)_darwin_amd64.tar.gz -C $(OUTPUT_DIR)/mac $(BINARY_NAME)_darwin_amd64
	tar -czf $(DIST_DIR)/$(BINARY_NAME)_darwin_arm64.tar.gz -C $(OUTPUT_DIR)/mac $(BINARY_NAME)_darwin_arm64
	# Windows (zip is more common, but keeping tar.gz for consistency or change to zip if preferred)
	tar -czf $(DIST_DIR)/$(BINARY_NAME)_windows_amd64.tar.gz -C $(OUTPUT_DIR)/windows $(BINARY_NAME)_windows_amd64.exe
	cd $(DIST_DIR) && sha256sum * > SHA256SUMS

# ------------------------------------------------------------------------------
# Docker
# ------------------------------------------------------------------------------

.PHONY: docker
docker:
	docker build -t $(BINARY_NAME):$(VERSION) .