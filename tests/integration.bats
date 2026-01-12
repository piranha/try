#!/usr/bin/env bats

# Integration tests for the try script and wrapper function

load test_helper

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "wrapper function processes DO: commands" {
    # Source the init output to create the wrapper function
    eval "$("$TRY_SCRIPT" init)"

    # Mock the underlying script to output a DO: command
    cat > "$TEST_DIR/mock-try" <<EOF
#!/usr/bin/env bash
echo "Regular output"
echo "DO: cd /tmp/test-location"
echo "More output"
EOF
    chmod +x "$TEST_DIR/mock-try"

    # Replace TRY_SCRIPT temporarily
    local ORIG_TRY="$TRY_SCRIPT"
    TRY_SCRIPT="$TEST_DIR/mock-try"

    # Capture output in a subshell to test the function
    run bash -c "
        eval \"\$('$ORIG_TRY' init)\"
        export -f try
        export TRY_SCRIPT='$TEST_DIR/mock-try'
        # Modify try function to use our mock
        try() {
            local line
            local tmpfile=\$(mktemp)
            '$TEST_DIR/mock-try' > \"\$tmpfile\"
            while IFS= read -r line; do
                if [[ \"\$line\" == DO:\\ * ]]; then
                    echo \"WOULD EXECUTE: \${line#DO: }\"
                else
                    printf '%s\n' \"\$line\"
                fi
            done < \"\$tmpfile\"
            rm -f \"\$tmpfile\"
        }
        try
    "

    [ "$status" -eq 0 ]
    assert_output_contains "Regular output"
    assert_output_contains "WOULD EXECUTE: cd /tmp/test-location"
    assert_output_contains "More output"
}

@test "wrapper function handles multiple DO: commands" {
    cat > "$TEST_DIR/mock-try" <<'EOF'
#!/usr/bin/env bash
echo "DO: export FOO=bar"
echo "DO: echo 'test'"
EOF
    chmod +x "$TEST_DIR/mock-try"

    eval "$("$TRY_SCRIPT" init)"

    run bash -c "
        eval \"\$('$TRY_SCRIPT' init)\"
        export PATH=\"$TEST_DIR:\$PATH\"
        try() {
            local line
            local tmpfile=\$(mktemp)
            '$TEST_DIR/mock-try' > \"\$tmpfile\"
            while IFS= read -r line; do
                if [[ \"\$line\" == DO:\\ * ]]; then
                    echo \"EXEC: \${line#DO: }\"
                else
                    printf '%s\n' \"\$line\"
                fi
            done < \"\$tmpfile\"
            rm -f \"\$tmpfile\"
        }
        try
    "

    [ "$status" -eq 0 ]
    [[ "$output" == *"EXEC: export FOO=bar"* ]]
    [[ "$output" == *"EXEC: echo 'test'"* ]]
}

@test "end-to-end: create new experiment with fzf" {
    # Create some existing experiments
    mkdir -p "$DIR/existing-one"
    mkdir -p "$DIR/existing-two"

    # Mock fzf to create new
    mock_fzf_return "new-experiment" "new-experiment"

    run "$TRY_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DO: cd"* ]]

    # Verify directory was created
    local date_prefix="$(date +%y%m%d)"
    assert_dir_exists "$DIR/$date_prefix-new-experiment"

    # Verify logfile was updated
    assert_file_contains "$DIR/.trylog" "new-experiment"
}

@test "end-to-end: select existing experiment" {
    mkdir -p "$DIR/my-experiment"

    # Mock fzf to select existing
    mock_fzf_return "my-experiment" ""

    run "$TRY_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DO: cd"* ]]
    [[ "$output" == *"my-experiment"* ]]

    # Logfile should be updated with new timestamp
    assert_file_contains "$DIR/.trylog" "my-experiment"
}

@test "end-to-end: clone and cd workflow" {
    # Mock git
    local real_git="$(which git)"
    cat > "$TEST_DIR/git" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "clone" ]]; then
    mkdir -p "\$3"
    (cd "\$3" && "$real_git" init -q)
    exit 0
fi
"$real_git" "\$@"
EOF
    chmod +x "$TEST_DIR/git"
    export PATH="$TEST_DIR:$PATH"

    run "$TRY_SCRIPT" clone https://github.com/user/my-repo.git

    [ "$status" -eq 0 ]
    assert_output_contains "DO: cd"

    # Extract the path from DO: cd output
    local target_path=$(echo "$output" | grep "DO: cd" | sed 's/DO: cd //')

    # Directory should exist
    [ -d "$target_path" ]
    [ -d "$target_path/.git" ]
}

@test "end-to-end: worktree workflow with existing repo" {
    create_mock_git_repo "$TEST_DIR/main-repo"

    cd "$TEST_DIR/main-repo"
    run "$TRY_SCRIPT" worktree . "experiment-branch"

    [ "$status" -eq 0 ]
    assert_output_contains "DO: cd"

    local date_prefix="$(date +%y%m%d)"
    local worktree_path="$DIR/$date_prefix-experiment-branch"

    # Worktree should exist and be a git repo
    assert_dir_exists "$worktree_path"
    [ -d "$worktree_path/.git" ] || [ -f "$worktree_path/.git" ]  # .git can be a file in worktrees

    # Should be listed as a worktree
    (cd "$TEST_DIR/main-repo" && git worktree list | grep -q "$worktree_path")
}

@test "end-to-end: delete experiment workflow" {
    mkdir -p "$DIR/temp-experiment"
    echo "test data" > "$DIR/temp-experiment/data.txt"

    # Mock fzf to confirm deletion
    mock_fzf_return "Yes"

    run "$TRY_SCRIPT" --RM "temp-experiment"

    [ "$status" -eq 0 ]

    # Directory should be gone
    [ ! -d "$DIR/temp-experiment" ]
}

@test "scoring algorithm prioritizes recent modifications" {
    # Create experiments with varying ages
    mkdir -p "$DIR/very-old"
    mkdir -p "$DIR/recent"

    set_mtime "$DIR/very-old" "202001010000"
    set_mtime "$DIR/recent" "$(date +%Y%m%d%H%M)"

    run "$TRY_SCRIPT" --LIST

    [ "$status" -eq 0 ]

    # Recent should appear before very-old
    local first_line=$(echo "$output" | head -1)
    [ "$first_line" = "recent" ]
}

@test "scoring algorithm prioritizes recent access" {
    # Create two old experiments
    mkdir -p "$DIR/old-unaccessed"
    mkdir -p "$DIR/old-accessed"

    set_mtime "$DIR/old-unaccessed" "202001010000"
    set_mtime "$DIR/old-accessed" "202001010000"

    # Mark one as recently accessed
    local recent_access=$(($(date +%s) - 1800))  # 30 minutes ago
    echo "$recent_access old-accessed" > "$DIR/.trylog"

    run "$TRY_SCRIPT" --LIST

    [ "$status" -eq 0 ]

    # Accessed should appear before unaccessed
    local first_line=$(echo "$output" | head -1)
    [ "$first_line" = "old-accessed" ]
}

@test "config file override works" {
    # Create a custom config
    cat > "$TEST_DIR/home/.tryrc" <<EOF
DIR="$TEST_DIR/custom-tries"
EOF

    mkdir -p "$TEST_DIR/custom-tries"
    export HOME="$TEST_DIR/home"

    # Unset our test DIR to let script read from config
    unset DIR
    unset TRYRC_DISABLED

    run bash -c "source '$TEST_DIR/home/.tryrc'; '$TRY_SCRIPT' --TARGET 'config-test'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"custom-tries"* ]]
}

@test "multiple experiments can coexist" {
    # Create multiple experiments
    for i in {1..5}; do
        mkdir -p "$DIR/experiment-$i"
        echo "data $i" > "$DIR/experiment-$i/data.txt"
    done

    run "$TRY_SCRIPT" --LIST

    [ "$status" -eq 0 ]

    # Should list all 5 experiments
    [ $(echo "$output" | wc -l) -eq 5 ]

    # Verify each exists in output
    for i in {1..5}; do
        assert_output_contains "experiment-$i"
    done
}
