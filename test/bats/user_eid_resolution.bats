#!/usr/bin/env bats

setup() {
    TEST_ROOT="$(mktemp -d)"
    PROGRAM=:
    JEM_CALLS_LOG="${TEST_ROOT}/jem.log"
    VZLIST=vzlist
    SED=sed
    mkdir -p "${TEST_ROOT}/pva-configs"
    inherit() { :; }
    include() { :; }
    source "${BATS_TEST_DIRNAME}/../../usr/lib/jelastic/modules/user.module"
    userPvaConfigPath() { printf '%s/%s\n' "${TEST_ROOT}/pva-configs" "$1"; }
}

teardown() {
    rm -rf "$TEST_ROOT"
}

add_eid_metadata() {
    local ctid="$1"
    local privatePath="$2"
    local eid="$3"
    mkdir -p "${privatePath}/.vza"
    printf '%s\n' "$eid" > "${privatePath}/.vza/eid.conf"
    printf '%s %s\n' "$ctid" "$privatePath" >> "${TEST_ROOT}/inventory"
}

vzlist() {
    [[ "$*" == '-a -H -o ctid,private' ]] || return 2
    [[ ! -f "${TEST_ROOT}/inventory" ]] || cat "${TEST_ROOT}/inventory"
}

@test "user EID resolver preserves the legacy PVA mapping" {
    printf '%s\n' '<ns1:veid>101</ns1:veid>' > "${TEST_ROOT}/pva-configs/env-legacy"
    vzlist() { printf 'unexpected inventory scan\n' > "${TEST_ROOT}/unexpected"; return 2; }

    run resolveUserContainerByEid env-legacy

    [ "$status" -eq 0 ]
    [ "$output" = '101' ]
    [ ! -e "${TEST_ROOT}/unexpected" ]
}

@test "user EID resolver maps VZ10 private-area metadata" {
    add_eid_metadata 102 "${TEST_ROOT}/private/102" 'env-vz10'

    run resolveUserContainerByEid env-vz10

    [ "$status" -eq 0 ]
    [ "$output" = '102' ]
}

@test "user EID resolver supports a private path containing spaces" {
    add_eid_metadata 103 "${TEST_ROOT}/private/path with spaces" 'env-spaces'

    run resolveUserContainerByEid env-spaces

    [ "$status" -eq 0 ]
    [ "$output" = '103' ]
}

@test "user EID resolver rejects an unsafe identifier before filesystem access" {
    vzlist() { printf 'unexpected inventory scan\n' > "${TEST_ROOT}/unexpected"; return 2; }

    run resolveUserContainerByEid '../escape'

    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ ! -e "${TEST_ROOT}/unexpected" ]
}

@test "user EID resolver ignores malformed metadata" {
    add_eid_metadata 104 "${TEST_ROOT}/private/104" 'first-value'
    printf '%s\n' 'env-target' 'second-line' > "${TEST_ROOT}/private/104/.vza/eid.conf"

    run resolveUserContainerByEid env-target

    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "user EID resolver fails closed when metadata is duplicated" {
    add_eid_metadata 105 "${TEST_ROOT}/private/105" 'env-duplicate'
    add_eid_metadata 106 "${TEST_ROOT}/private/106" 'env-duplicate'

    run resolveUserContainerByEid env-duplicate

    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "user container path resolution delegates typed arguments to resolvepath adapter" {
    vzctPath() {
        printf '%s\n' "$1" "$2" > "${TEST_ROOT}/vzct-path.args"
        printf '%s%s\n' "$1" "$2"
    }

    run resolveUserContainerPath "${TEST_ROOT}/container root" '/var/www/path with spaces'

    [ "$status" -eq 0 ]
    [ "$output" = "${TEST_ROOT}/container root/var/www/path with spaces" ]
    [ "$(sed -n '1p' "${TEST_ROOT}/vzct-path.args")" = "${TEST_ROOT}/container root" ]
    [ "$(sed -n '2p' "${TEST_ROOT}/vzct-path.args")" = '/var/www/path with spaces' ]
}

@test "user container path resolution rejects an empty path" {
    vzctPath() { printf 'unexpected\n' > "${TEST_ROOT}/unexpected"; }

    run resolveUserContainerPath "${TEST_ROOT}/container" ''

    [ "$status" -eq 1 ]
    [ ! -e "${TEST_ROOT}/unexpected" ]
}

@test "user add pre-callback returns success after resolving application ownership" {
    log() { :; }
    isFunction() { declare -F "$1" >/dev/null; }
    getAppUserInfo() {
        _UID=700
        _GUID=700
        _homedir=/var/www
    }
    writeJSONResponseErr() { printf 'unexpected error response\n'; }
    die() { return 99; }

    run preAddCallback -d

    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
