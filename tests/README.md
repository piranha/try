# Test Suite for `try` Script

This directory contains comprehensive tests for the `try` bash script using the [bats-core](https://github.com/bats-core/bats-core) testing framework.

## Setup

### Install bats-core

**macOS (Homebrew):**
```bash
brew install bats-core
```

**Linux (from source):**
```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

**npm (alternative):**
```bash
npm install -g bats
```

### Optional: Install helper libraries (recommended)

These provide better assertions and support:

```bash
# Clone into tests/test_helper/
cd tests
git clone https://github.com/bats-core/bats-support.git test_helper/bats-support
git clone https://github.com/bats-core/bats-assert.git test_helper/bats-assert
```

If installed, the test helper will automatically load them.

## Running Tests

### Run all tests:
```bash
bats tests/
```

### Run a specific test file:
```bash
bats tests/basic_functions.bats
bats tests/commands.bats
bats tests/integration.bats
```

### Run with verbose output:
```bash
bats -p tests/  # Parallel execution
bats -t tests/  # Tap output
```

### Run a specific test:
```bash
bats tests/basic_functions.bats -f "record creates logfile"
```

## Test Structure

```
tests/
├── README.md                 # This file
├── test_helper.bash          # Shared helper functions
├── basic_functions.bats      # Tests for internal functions
├── commands.bats             # Tests for CLI commands
└── integration.bats          # End-to-end integration tests
```

### Test Files

- **basic_functions.bats**: Tests core functionality like `--LIST`, `--TARGET`, `record()`, `mtime()`, etc.
- **commands.bats**: Tests command-line operations: `clone`, `worktree`, `--RM`, etc.
- **integration.bats**: Tests complete workflows including the wrapper function, scoring algorithm, and real-world scenarios

## Test Helpers

The `test_helper.bash` file provides:

- `setup_test_env()`: Creates isolated test environment with temp directories
- `teardown_test_env()`: Cleans up after tests
- `create_mock_git_repo(path)`: Creates a minimal git repository for testing
- `mock_fzf_select()`: Mocks fzf for non-interactive testing
- `mock_fzf_return(value)`: Makes fzf return a specific value
- `set_mtime(file, timestamp)`: Sets file modification time (cross-platform)
- `assert_dir_exists(dir)`: Asserts a directory exists
- `assert_file_contains(file, text)`: Asserts file contains text
- `assert_output_contains(text)`: Asserts command output contains text

## Writing New Tests

Example test:

```bash
@test "description of what this tests" {
    # Arrange
    mkdir -p "$DIR/test-data"
    echo "content" > "$DIR/test-data/file.txt"

    # Act
    run "$TRY_SCRIPT" some-command

    # Assert
    [ "$status" -eq 0 ]
    assert_output_contains "expected output"
    assert_dir_exists "$DIR/result"
}
```

### Best Practices

1. **Use descriptive test names**: `"clone creates dated directory"` not `"test clone"`
2. **Test one thing per test**: Keep tests focused and atomic
3. **Use test helpers**: Don't repeat setup/teardown logic
4. **Mock external dependencies**: Mock `git`, `fzf`, network calls
5. **Test edge cases**: Empty inputs, special characters, missing files
6. **Clean up**: Always use `teardown()` to remove test artifacts

## Skipping Tests

To skip a test that requires external resources:

```bash
@test "something that needs network" {
    skip "Requires network access"
    # test code
}
```

Or conditionally skip:

```bash
@test "darwin-specific test" {
    [[ "$OSTYPE" != "darwin"* ]] && skip "macOS only"
    # test code
}
```

## CI Integration

To run tests in CI:

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install bats
        run: |
          git clone https://github.com/bats-core/bats-core.git
          cd bats-core
          sudo ./install.sh /usr/local
      - name: Run tests
        run: bats tests/
```

## Coverage

Currently tested:
- ✅ Internal functions (`record`, `mtime`, `log`)
- ✅ Command parsing and routing
- ✅ `--LIST` scoring algorithm
- ✅ `--TARGET` directory creation
- ✅ `clone` command with URL parsing
- ✅ `worktree` creation and management
- ✅ `--RM` deletion with confirmation
- ✅ Interactive selection (via mocked fzf)
- ✅ Wrapper function DO: command execution
- ✅ Config file loading
- ✅ Edge cases and error handling

## Troubleshooting

### Tests fail with "command not found"
Ensure the `try` script is executable:
```bash
chmod +x try
```

### fzf tests hang
The test suite mocks fzf. If tests hang, check that `mock_fzf_*` helpers are called in `setup()`

### Permission errors
Tests create temp directories. Ensure `/tmp` is writable.

### Git tests fail
Some tests create git repos. Ensure git is installed and configured:
```bash
git config --global user.email "test@example.com"
git config --global user.name "Test User"
```

## Debugging Tests

Run with `set -x` for detailed output:
```bash
bash -x $(which bats) tests/basic_functions.bats
```

Print variables during test:
```bash
@test "debug example" {
    echo "DIR=$DIR" >&3
    echo "output=$output" >&3
}
```

## Contributing

When adding features to `try`:
1. Write tests first (TDD)
2. Ensure all existing tests pass
3. Add tests for new functionality
4. Update this README if needed
