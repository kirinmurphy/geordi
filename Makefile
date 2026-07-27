SWIFT := swift
SWIFT_FLAGS := --disable-sandbox

.PHONY: build install-dev install-shortcut test test-unit test-ui fixtures format format-check verify run clean

build:
	$(SWIFT) build $(SWIFT_FLAGS)
	./scripts/package-app.sh

install-dev: build
	./scripts/install-dev.sh

install-shortcut: install-dev
	./scripts/install-desktop-shortcut.sh

test: test-unit test-ui

test-unit:
	$(SWIFT) test $(SWIFT_FLAGS)

test-ui:
	./scripts/ui-smoke.sh

fixtures:
	$(SWIFT) run $(SWIFT_FLAGS) hal-fixture-validator

format:
	xcrun swift-format format --in-place --recursive Package.swift Sources Tests

format-check:
	xcrun swift-format lint --strict --recursive Package.swift Sources Tests

verify: format-check test-unit fixtures build test-ui

run: install-dev
	open -n "$(HOME)/Applications/HAL.app"

clean:
	$(SWIFT) package clean
