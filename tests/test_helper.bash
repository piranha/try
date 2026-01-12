# Test helper functions for try script tests

# Load bats support libraries
load_bats_libs() {
    # If using bats-support and bats-assert
    if [ -f "tests/test_helper/bats-support/load.bash" ]; then
        load "test_helper/bats-support/load.bash"
        load "test_helper/bats-assert/load.bash"
    fi
}

# Setup a clean test environment
setup_test_env() {
    export TEST_DIR="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/try-test.XXXXXX")"
    export ORIG_DIR="$DIR"
    export DIR="$TEST_DIR/tries"
    export HOME="$TEST_DIR/home"

    mkdir -p "$DIR"
    mkdir -p "$HOME"

    # Path to the try script
    export TRY_SCRIPT="${BATS_TEST_DIRNAME}/../try"

    # Disable user config
    export TRYRC_DISABLED=1
}

# Cleanup test environment
teardown_test_env() {
    if [ -n "${TEST_DIR:-}" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
    if [ -n "${ORIG_DIR:-}" ]; then
        export DIR="$ORIG_DIR"
    fi
}

# Create a mock git repository
create_mock_git_repo() {
    local repo_path="$1"
    mkdir -p "$repo_path"
    (
        cd "$repo_path"
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test User"
        echo "test" > README.md
        git add README.md
        git commit -q -m "Initial commit"
    )
}

# Mock fzf that returns the first argument
mock_fzf_select() {
    cat > "$TEST_DIR/fzf" <<'EOF'
#!/usr/bin/env bash
# Mock fzf that selects the first line or query
if [[ "$*" == *--print-query* ]]; then
    # Print query first, then selection
    while IFS= read -r line; do
        if [ -z "${first_line:-}" ]; then
            first_line="$line"
        fi
    done

    # Extract query from args
    for arg in "$@"; do
        if [[ "$prev_arg" == "--query" ]]; then
            echo "$arg"  # Print query
            echo "${first_line:-$arg}"  # Print selection (or query if no input)
            exit 0
        fi
        prev_arg="$arg"
    done

    echo ""  # Empty query
    echo "${first_line:-}"  # First line as selection
else
    # Just return first line
    head -1
fi
EOF
    chmod +x "$TEST_DIR/fzf"
    export PATH="$TEST_DIR:$PATH"
}

# Mock fzf that returns specific value
mock_fzf_return() {
    local return_value="$1"
    local query="${2:-}"

    cat > "$TEST_DIR/fzf" <<EOF
#!/usr/bin/env bash
if [[ "\$*" == *--print-query* ]]; then
    echo "$query"
    echo "$return_value"
else
    echo "$return_value"
fi
EOF
    chmod +x "$TEST_DIR/fzf"
    export PATH="$TEST_DIR:$PATH"
}

# Set a file's modification time (cross-platform)
set_mtime() {
    local file="$1"
    local timestamp="$2"  # Format: YYYYMMDDhhmm

    if [[ "$OSTYPE" == "darwin"* ]]; then
        touch -t "$timestamp" "$file"
    else
        touch -t "$timestamp" "$file"
    fi
}

# Get current date in YYMMDD format
get_date_prefix() {
    date +%y%m%d
}

# Assert directory exists
assert_dir_exists() {
    local dir="$1"
    [ -d "$dir" ] || {
        echo "Directory does not exist: $dir" >&2
        return 1
    }
}

# Assert file contains text
assert_file_contains() {
    local file="$1"
    local text="$2"
    grep -q "$text" "$file" || {
        echo "File '$file' does not contain '$text'" >&2
        echo "Contents:" >&2
        cat "$file" >&2
        return 1
    }
}

# Assert output contains text
assert_output_contains() {
    local text="$1"
    echo "$output" | grep -q "$text" || {
        echo "Output does not contain '$text'" >&2
        echo "Output was:" >&2
        echo "$output" >&2
        return 1
    }
}
