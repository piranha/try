#!/usr/bin/env bats

# Tests for command-line operations

load test_helper

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "clone without URL shows usage" {
    run "$TRY_SCRIPT" clone

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "clone with GitHub URL creates dated directory" {
    skip "Requires network and real git"
    # This test would need network access
    # You can enable it for integration testing

    run "$TRY_SCRIPT" clone https://github.com/anthropics/courses.git

    [ "$status" -eq 0 ]
    [[ "$output" == *"DO: cd"* ]]

    # Check directory was created
    local date_prefix="$(date +%y%m%d)"
    assert_dir_exists "$DIR/$date_prefix-courses"
}

@test "clone extracts repo name correctly" {
    # Test with .git suffix
    run bash -c "basename 'https://github.com/user/repo.git' | sed 's/\\.git$//'"
    [ "$output" = "repo" ]

    # Test without .git suffix
    run bash -c "basename 'https://github.com/user/repo' | sed 's/\\.git$//'"
    [ "$output" = "repo" ]
}

@test "clone outputs DO: cd command" {
    # Mock git to avoid network access
    local real_git="$(which git)"
    cat > "$TEST_DIR/git" <<EOF
#!/usr/bin/env bash
# Mock git clone
if [[ "\$1" == "clone" ]]; then
    mkdir -p "\$3"
    cd "\$3"
    "$real_git" init -q
    exit 0
fi
"$real_git" "\$@"
EOF
    chmod +x "$TEST_DIR/git"
    export PATH="$TEST_DIR:$PATH"

    run "$TRY_SCRIPT" clone https://github.com/user/test-repo.git

    [ "$status" -eq 0 ]
    assert_output_contains "DO: cd"
    assert_output_contains "test-repo"
}

@test "worktree without arguments uses current directory" {
    create_mock_git_repo "$TEST_DIR/source"

    cd "$TEST_DIR/source"
    run "$TRY_SCRIPT" worktree .

    [ "$status" -eq 0 ]
    [[ "$output" == *"DO: cd"* ]]

    # Should create worktree with source basename
    local date_prefix="$(date +%y%m%d)"
    assert_dir_exists "$DIR/$date_prefix-source"
}

@test "worktree with source creates worktree" {
    create_mock_git_repo "$TEST_DIR/source"

    run "$TRY_SCRIPT" worktree "$TEST_DIR/source"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DO: cd"* ]]

    local date_prefix="$(date +%y%m%d)"
    assert_dir_exists "$DIR/$date_prefix-source"
}

@test "worktree with custom target name" {
    create_mock_git_repo "$TEST_DIR/source"

    run "$TRY_SCRIPT" worktree "$TEST_DIR/source" "my-experiment"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DO: cd"* ]]
    [[ "$output" == *"my-experiment"* ]]

    local date_prefix="$(date +%y%m%d)"
    assert_dir_exists "$DIR/$date_prefix-my-experiment"
}

@test "worktree strips date prefix from source when used as target" {
    create_mock_git_repo "$DIR/250101-old-experiment"

    run "$TRY_SCRIPT" worktree "$DIR/250101-old-experiment"

    [ "$status" -eq 0 ]

    # Should create new dated directory with stripped name
    local date_prefix="$(date +%y%m%d)"
    [[ "$output" == *"$date_prefix-old-experiment"* ]]
}

@test "worktree fails for non-git directory" {
    mkdir -p "$TEST_DIR/not-a-repo"

    run "$TRY_SCRIPT" worktree "$TEST_DIR/not-a-repo"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Not inside of a git repo"* ]]
}

@test "dot command is alias for worktree" {
    create_mock_git_repo "$TEST_DIR/source"

    run "$TRY_SCRIPT" . "$TEST_DIR/source"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DO: cd"* ]]

    local date_prefix="$(date +%y%m%d)"
    assert_dir_exists "$DIR/$date_prefix-source"
}

@test "https URL is treated as clone" {
    # Mock git
    local real_git="$(which git)"
    cat > "$TEST_DIR/git" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "clone" ]]; then
    mkdir -p "\$3"
    cd "\$3"
    "$real_git" init -q
    exit 0
fi
"$real_git" "\$@"
EOF
    chmod +x "$TEST_DIR/git"
    export PATH="$TEST_DIR:$PATH"

    run "$TRY_SCRIPT" https://github.com/user/repo.git

    [ "$status" -eq 0 ]
    [[ "$output" == *"DO: cd"* ]]
}

@test "--RM prompts for confirmation" {
    mkdir -p "$DIR/test-experiment"

    # Mock fzf to return "No"
    mock_fzf_return "No"

    run "$TRY_SCRIPT" --RM "test-experiment"

    [ "$status" -eq 0 ]
    # Directory should still exist
    assert_dir_exists "$DIR/test-experiment"
}

@test "--RM deletes on Yes confirmation" {
    mkdir -p "$DIR/test-experiment"
    echo "test" > "$DIR/test-experiment/file.txt"

    # Mock fzf to return "Yes"
    mock_fzf_return "Yes"

    run "$TRY_SCRIPT" --RM "test-experiment"

    [ "$status" -eq 0 ]
    # Directory should be deleted
    [ ! -d "$DIR/test-experiment" ]
}

@test "--RM without argument shows error" {
    run "$TRY_SCRIPT" --RM

    [ "$status" -eq 0 ]
    [[ "$output" == *"provide argument"* ]] || [[ "$stderr" == *"provide argument"* ]]
}

@test "default behavior with query creates new directory" {
    # Mock fzf to return query as selection (no existing match)
    mock_fzf_return "new-experiment" "new-experiment"

    run "$TRY_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DO: cd"* ]]

    local date_prefix="$(date +%y%m%d)"
    assert_dir_exists "$DIR/$date_prefix-new-experiment"
}

@test "default behavior with selection chooses existing" {
    mkdir -p "$DIR/existing-experiment"

    # Mock fzf to return existing directory
    mock_fzf_return "existing-experiment" ""

    run "$TRY_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DO: cd"* ]]
    [[ "$output" == *"existing-experiment"* ]]
}

@test "default behavior with query argument" {
    # Mock fzf to use query
    mock_fzf_return "query-test" "query-test"

    run "$TRY_SCRIPT" "query-test"

    [ "$status" -eq 0 ]

    local date_prefix="$(date +%y%m%d)"
    [[ "$output" == *"$date_prefix-query-test"* ]] || [[ "$output" == *"query-test"* ]]
}
