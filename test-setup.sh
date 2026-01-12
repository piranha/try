#!/usr/bin/env bash
# Quick setup script for the try test suite

set -e

echo "=== Try Script Test Suite Setup ==="
echo ""

# Check if bats is installed
if ! command -v bats >/dev/null 2>&1; then
    echo "❌ bats-core is not installed"
    echo ""
    echo "Install it with:"
    echo "  macOS:  brew install bats-core"
    echo "  Linux:  See https://github.com/bats-core/bats-core#installation"
    echo "  npm:    npm install -g bats"
    echo ""
    read -p "Try to install with Homebrew now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v brew >/dev/null 2>&1; then
            brew install bats-core
        else
            echo "Homebrew not found. Please install manually."
            exit 1
        fi
    else
        exit 1
    fi
else
    echo "✅ bats-core is installed: $(bats --version)"
fi

# Check for helper libraries
echo ""
if [ -d "tests/test_helper/bats-support" ] && [ -d "tests/test_helper/bats-assert" ]; then
    echo "✅ bats helper libraries are installed"
else
    echo "⚠️  bats helper libraries not found (optional but recommended)"
    read -p "Install helper libraries? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "Installing helper libraries..."
        mkdir -p tests/test_helper

        if [ ! -d "tests/test_helper/bats-support" ]; then
            git clone https://github.com/bats-core/bats-support.git tests/test_helper/bats-support
        fi

        if [ ! -d "tests/test_helper/bats-assert" ]; then
            git clone https://github.com/bats-core/bats-assert.git tests/test_helper/bats-assert
        fi

        echo "✅ Helper libraries installed"
    fi
fi

# Check if try script is executable
echo ""
if [ -x "./try" ]; then
    echo "✅ try script is executable"
else
    echo "⚠️  try script is not executable"
    chmod +x ./try
    echo "✅ Made try script executable"
fi

# Check git config
echo ""
if git config user.email >/dev/null 2>&1; then
    echo "✅ git is configured"
else
    echo "⚠️  git user not configured (needed for some tests)"
    echo "Run: git config --global user.email 'you@example.com'"
    echo "     git config --global user.name 'Your Name'"
fi

# Run a quick test
echo ""
echo "=== Running a quick test ==="
if bats tests/basic_functions.bats -f "init outputs valid shell function"; then
    echo ""
    echo "✅ Test suite is working!"
else
    echo ""
    echo "❌ Test failed. Please check the setup."
    exit 1
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Run tests with:"
echo "  make test              # Run all tests"
echo "  bats tests/            # Run all tests"
echo "  bats tests/commands.bats  # Run specific test file"
echo ""
echo "See tests/README.md for more information"
