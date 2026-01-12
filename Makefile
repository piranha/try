.PHONY: test test-basic test-commands test-integration test-verbose help install-bats install-helpers

help:
	@echo "Try Script Test Suite"
	@echo ""
	@echo "Available targets:"
	@echo "  make test              - Run all tests"
	@echo "  make test-basic        - Run basic function tests"
	@echo "  make test-commands     - Run command tests"
	@echo "  make test-integration  - Run integration tests"
	@echo "  make test-verbose      - Run all tests with verbose output"
	@echo "  make install-bats      - Install bats-core (macOS)"
	@echo "  make install-helpers   - Install bats helper libraries"
	@echo ""

test:
	@echo "Running all tests..."
	@bats tests/

test-basic:
	@echo "Running basic function tests..."
	@bats tests/basic_functions.bats

test-commands:
	@echo "Running command tests..."
	@bats tests/commands.bats

test-integration:
	@echo "Running integration tests..."
	@bats tests/integration.bats

test-verbose:
	@echo "Running all tests (verbose)..."
	@bats -p tests/

install-bats:
	@echo "Installing bats-core via Homebrew..."
	@if command -v brew >/dev/null 2>&1; then \
		brew install bats-core; \
	else \
		echo "Homebrew not found. Please install manually:"; \
		echo "https://github.com/bats-core/bats-core#installation"; \
	fi

install-helpers:
	@echo "Installing bats helper libraries..."
	@mkdir -p tests/test_helper
	@if [ ! -d "tests/test_helper/bats-support" ]; then \
		git clone https://github.com/bats-core/bats-support.git tests/test_helper/bats-support; \
	else \
		echo "bats-support already installed"; \
	fi
	@if [ ! -d "tests/test_helper/bats-assert" ]; then \
		git clone https://github.com/bats-core/bats-assert.git tests/test_helper/bats-assert; \
	else \
		echo "bats-assert already installed"; \
	fi
	@echo "Helper libraries installed successfully"
