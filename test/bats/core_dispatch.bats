#!/usr/bin/env bats

setup() {
    TEST_ROOT="$(mktemp -d)"
    PROGRAM=:
    isFunction() { declare -F "$1" >/dev/null; }
    source "${BATS_TEST_DIRNAME}/../../usr/lib/jelastic/libs/core.lib"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

prepare_do_action_fixture() {
    FIXTURE_MODULE="${TEST_ROOT}/fixture.module"

    : > "${TEST_ROOT}/default.lib"
    cat > "$FIXTURE_MODULE" <<EOF
function preCreateCallback() {
    printf '{"result":"4099","message":"Missing param OSTEMPLATE"}\\n'
    return 37
}
function doCreate() {
    printf 'backend invoked\\n' > "${TEST_ROOT}/backend.calls"
}
EOF

    MANAGE_PROGRAM_NAME=jem
    MANAGE_BINARY_NAME=jem
    MANAGE_DEFAULT_ACTIONS="${TEST_ROOT}/default.lib"
    MANAGE_DEFAULT_MODULES_PATH="$TEST_ROOT"
    MANAGE_MODULES_PATH=("$TEST_ROOT")
    JEM_CALLS_LOG="${TEST_ROOT}/jem.log"
    OVERRIDE_DIR="${TEST_ROOT}/overrides"
    CUSTOMIZATIONS_DIR="${TEST_ROOT}/customizations"
    SED=sed
    MANAGE_KILL_TARGET=999999
    _manageFindModule() { printf '%s\n' "$FIXTURE_MODULE"; }
}

@test "pre-action failure skips action and post-action callbacks" {
    preCreateCallback() { printf 'pre\n' >> "${TEST_ROOT}/calls"; return 37; }
    doCreate() { printf 'action\n' >> "${TEST_ROOT}/calls"; }
    postCreateCallback() { printf 'post\n' >> "${TEST_ROOT}/calls"; }

    run executeActionLifecycle Create --ctid 101

    if [ "$status" -ne 37 ]; then
        printf 'unexpected status=%s output=%s\n' "$status" "$output" >&3
        false
    fi
    [ "$(cat "${TEST_ROOT}/calls")" = 'pre' ]
}

@test "doAction returns one validation response and never invokes the backend" {
    prepare_do_action_fixture

    run doAction fixture Create --timeout=10

    if [ "$status" -ne 37 ]; then
        printf 'unexpected status=%s output=%s\n' "$status" "$output" >&3
        false
    fi
    [ "$(grep -c '^{"result"' <<< "$output")" -eq 1 ]
    [ "$output" = '{"result":"4099","message":"Missing param OSTEMPLATE"}' ]
    [ ! -e "${TEST_ROOT}/backend.calls" ]
}

@test "successful lifecycle runs pre action and post in order" {
    preCreateCallback() { printf 'pre:%s\n' "$*" >> "${TEST_ROOT}/calls"; }
    doCreate() { printf 'action:%s\n' "$*" >> "${TEST_ROOT}/calls"; }
    postCreateCallback() { printf 'post:%s\n' "$*" >> "${TEST_ROOT}/calls"; }

    run executeActionLifecycle Create --ctid 101

    [ "$status" -eq 0 ]
    [ "$(cat "${TEST_ROOT}/calls")" = $'pre:--ctid 101\naction:--ctid 101\npost:--ctid 101' ]
}

@test "action failure skips post-action callback and preserves status" {
    preCreateCallback() { :; }
    doCreate() { printf 'action\n' >> "${TEST_ROOT}/calls"; return 42; }
    postCreateCallback() { printf 'post\n' >> "${TEST_ROOT}/calls"; }

    run executeActionLifecycle Create

    [ "$status" -eq 42 ]
    [ "$(cat "${TEST_ROOT}/calls")" = 'action' ]
}

@test "public action registry excludes internal and docker-prefixed helpers" {
    doList() { :; }
    doSetup() { :; }
    dofwset() { :; }
    dockerContainerRootForId() { :; }
    dockerResponseParseJson() { :; }

    run listPublicActions

    [ "$status" -eq 0 ]
    grep -Fxq List <<< "$output"
    grep -Fxq Setup <<< "$output"
    grep -Fxq fwset <<< "$output"
    ! grep -Fq ckerContainerRootForId <<< "$output"
    ! grep -Fq ckerResponseParseJson <<< "$output"
    ! grep -Fxq Action <<< "$output"
}

@test "public action resolution is exact and case-insensitive" {
    doGetInfo() { :; }
    dockerGetInfoCache() { :; }

    run resolvePublicAction getinfo
    [ "$status" -eq 0 ]
    [ "$output" = 'GetInfo' ]

    run resolvePublicAction Info
    [ "$status" -eq 1 ]
    [ -z "$output" ]

    run resolvePublicAction ckerGetInfoCache
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "legacy lowercase public actions remain resolvable" {
    dogetPCSTemplate() { :; }
    doisEnabled() { :; }
    dosetupUtils() { :; }

    run resolvePublicAction getpcstemplate
    [ "$status" -eq 0 ]
    [ "$output" = 'getPCSTemplate' ]

    run resolvePublicAction isenabled
    [ "$status" -eq 0 ]
    [ "$output" = 'isEnabled' ]

    run resolvePublicAction setuputils
    [ "$status" -eq 0 ]
    [ "$output" = 'setupUtils' ]
}
