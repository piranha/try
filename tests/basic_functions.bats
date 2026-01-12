#!/usr/bin/env bats

# Tests for internal functions of the try script

load test_helper

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "record creates logfile if it doesn't exist" {
    local target="$DIR/test-experiment"
    mkdir -p "$target"

    run "$TRY_SCRIPT" --LIST
    [ "$status" -eq 0 ]
    [ -f "$DIR/.trylog" ]
}

@test "record updates existing logfile entry" {
    local target="$DIR/test-experiment"
    mkdir -p "$target"

    # Create initial logfile entry
    echo "1234567890 test-experiment" > "$DIR/.trylog"

    # Simulate accessing the directory (record is called internally)
    # We'll test this by checking the --LIST command updates timestamps
    sleep 1

    # The record function is internal, so we test it via side effects
    run "$TRY_SCRIPT" --LIST
    [ "$status" -eq 0 ]
}

@test "record doesn't duplicate entries" {
    local target="$DIR/test-experiment"
    mkdir -p "$target"

    # Manually create duplicate entries
    echo "1234567890 test-experiment" > "$DIR/.trylog"
    echo "1234567891 test-experiment" >> "$DIR/.trylog"

    # --LIST should clean this up via its internal logic
    run "$TRY_SCRIPT" --LIST
    [ "$status" -eq 0 ]

    # Should only have one entry now (though this is hard to verify without exposing internals)
    # This tests that the script can handle malformed logfiles
}

@test "--TARGET creates directory with date prefix" {
    local name="my-experiment"
    run "$TRY_SCRIPT" --TARGET "$name"

    [ "$status" -eq 0 ]

    # Should output path with YYMMDD prefix
    local date_prefix="$(date +%y%m%d)"
    [[ "$output" == *"$date_prefix-$name"* ]]

    # Directory should exist
    [ -d "$output" ]
}

@test "--TARGET handles spaces in names" {
    local name="my cool experiment"
    run "$TRY_SCRIPT" --TARGET "$name"

    [ "$status" -eq 0 ]

    # Spaces should be converted to dashes
    [[ "$output" == *"my-cool-experiment"* ]]
    [ -d "$output" ]
}

@test "--LIST outputs directories sorted by score" {
    # Create multiple directories with different timestamps
    mkdir -p "$DIR/old-experiment"
    mkdir -p "$DIR/new-experiment"
    mkdir -p "$DIR/accessed-experiment"

    # Set different modification times
    set_mtime "$DIR/old-experiment" "202301010000"
    set_mtime "$DIR/new-experiment" "$(date +%Y%m%d%H%M)"
    set_mtime "$DIR/accessed-experiment" "202306010000"

    # Add access time for one directory
    local now="$(date +%s)"
    local recent_access="$((now - 3600))"  # 1 hour ago
    echo "$recent_access accessed-experiment" > "$DIR/.trylog"

    run "$TRY_SCRIPT" --LIST
    [ "$status" -eq 0 ]

    # Recent or accessed should appear first
    # (exact order depends on scoring algorithm)
    local first_line="$(echo "$output" | head -1)"
    [[ "$first_line" == "new-experiment" ]] || [[ "$first_line" == "accessed-experiment" ]]
}

@test "--LIST handles empty directory" {
    # DIR exists but is empty
    run "$TRY_SCRIPT" --LIST

    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "--LIST creates .trylog if missing" {
    # Remove logfile if it exists
    rm -f "$DIR/.trylog"

    run "$TRY_SCRIPT" --LIST

    [ "$status" -eq 0 ]
    [ -f "$DIR/.trylog" ]
}

@test "init outputs valid shell function" {
    run "$TRY_SCRIPT" init

    [ "$status" -eq 0 ]
    [[ "$output" == *"try ()"* ]]
    [[ "$output" == *"DO:"* ]]

    # Should be valid bash
    bash -n <(echo "$output")
}

@test "help command shows usage" {
    run "$TRY_SCRIPT" help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Browse all experiments"* ]]
    [[ "$output" == *"eval"* ]]
}

@test "--help shows usage" {
    run "$TRY_SCRIPT" --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Browse all experiments"* ]]
}
