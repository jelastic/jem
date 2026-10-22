#!/bin/bash

# Characterization tests for envId password-key selection.  No real password
# material is used: the mocked openssl records only the selected key.
set -euo pipefail

testRoot=$(mktemp -d)
trap 'rm -rf -- "$testRoot"' EXIT

include() { :; }
log() { :; }
writeJSONResponseErr() { :; }
die() { return 1; }
ACTIONS_LOG=/dev/null
DECPASSWD_OS_RELEASE="$testRoot/os-release"
TEST_UUID=
TEST_VZLIST_CALLS="$testRoot/vzlist.calls"

vzlist() {
    printf '<%s>' "$@" >> "$TEST_VZLIST_CALLS"
    printf '\n' >> "$TEST_VZLIST_CALLS"
    case "$*" in
        "$__CTID -Ho private" ) printf '%s\n' "$TEST_PRIVATE" ;;
        "-a -H -o uuid $__CTID" ) printf '%s\n' "$TEST_UUID" ;;
        * ) return 1 ;;
    esac
}

openssl() {
    if [[ "${1:-}" == version ]]; then
        printf '%s\n' 'OpenSSL 3.2.0 test'
        return 0
    fi
    local argument
    for argument in "$@"; do
        case "$argument" in
            pass:*) printf '%s' "${argument#pass:}" > "$TEST_CAPTURE" ;;
        esac
    done
    printf '%s\n' 'test-password'
}

assertEquals() {
    [[ "$1" == "$2" ]] || {
        printf 'expected %q, got %q\n' "$1" "$2" >&2
        exit 1
    }
}

# The production library is sourced by JEM without errexit.  Its host-version
# probe may have no matching release string in a generic test environment.
set +e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/usr/lib/jelastic/libs/decrypt-passwd.lib"
set -e

TEST_PRIVATE="$testRoot/private-with-eid"
TEST_CAPTURE="$testRoot/key"
mkdir -p "$TEST_PRIVATE/.vza"
printf '%s\n' 'environment-id-for-test' > "$TEST_PRIVATE/.vza/eid.conf"
printf '%s\n' 'VERSION_ID="10"' > "$DECPASSWD_OS_RELEASE"
TEST_UUID='11111111-2222-3333-4444-555555555555'
__CTID=12345
getPassword 'envId:legacy-payload:modern-payload' >/dev/null
assertEquals 'environment-id-for-test' "$(<"$TEST_CAPTURE")"
assertEquals '<12345><-Ho><private>' "$(<"$TEST_VZLIST_CALLS")"

TEST_PRIVATE="$testRoot/private-without-eid"
mkdir -p "$TEST_PRIVATE"
TEST_UUID='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
> "$TEST_VZLIST_CALLS"
__CTID=67890
getPassword 'envId:legacy-payload:modern-payload' >/dev/null
assertEquals 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' "$(<"$TEST_CAPTURE")"
assertEquals $'<67890><-Ho><private>\n<-a><-H><-o><uuid><67890>' "$(<"$TEST_VZLIST_CALLS")"

printf '%s\n' 'VERSION_ID="7.9"' > "$DECPASSWD_OS_RELEASE"
TEST_UUID='ffffffff-1111-2222-3333-444444444444'
> "$TEST_VZLIST_CALLS"
__CTID=67890
getPassword 'envId:legacy-payload:modern-payload' >/dev/null
assertEquals '67890' "$(<"$TEST_CAPTURE")"
assertEquals '<67890><-Ho><private>' "$(<"$TEST_VZLIST_CALLS")"

printf '%s\n' 'VERSION_ID="10"' > "$DECPASSWD_OS_RELEASE"
TEST_UUID='not-a-native-uuid'
__CTID=67890
if getEnvIdPasswordKey >/dev/null; then
    printf '%s\n' 'VZ10 accepted an invalid native UUID' >&2
    exit 1
fi

# Exercise the actual OpenSSL 3 path as well, using a generated test payload.
unset -f openssl
if command openssl version | grep -qE '^OpenSSL 3\.'; then
    TEST_PRIVATE="$testRoot/private-with-eid"
    __CTID=12345
    cipherArgs=( -aes-256-cbc -pbkdf2 -md sha512 -iter 10000 -salt
        -S 429488b2f3870b4a -iv dcb9fe5ecb4011cd20114119930aadc3 )
    encrypted=$(printf '%s' 'test-password' |
        command openssl enc -e -a -pass 'pass:environment-id-for-test' "${cipherArgs[@]}")
    assertEquals 'test-password' "$(getPassword "envId:legacy-payload:${encrypted}")"

    TEST_PRIVATE="$testRoot/private-without-eid"
    TEST_UUID='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
    __CTID=67890
    encrypted=$(printf '%s' 'test-password' |
        command openssl enc -e -a -pass 'pass:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' "${cipherArgs[@]}")
    assertEquals 'test-password' "$(getPassword "envId:legacy-payload:${encrypted}")"
fi

printf '%s\n' 'decrypt-passwd tests: OK'
