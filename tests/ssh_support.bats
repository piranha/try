#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "git@ URL is treated as clone" {
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

    run "$TRY_SCRIPT" git@github.com:user/repo.git

    [ "$status" -eq 0 ]
    assert_output_contains "DO: cd"
    # It should create a directory based on the repo name, not the URL
    assert_output_contains "repo"
}
