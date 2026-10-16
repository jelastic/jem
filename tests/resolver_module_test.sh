#!/usr/bin/env bash

set -eo pipefail

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

function inherit() { :; }
function include() { :; }
function program_stub() { :; }
function writeJSONResponseErr() { :; }
function log() { printf '%s\n' "$*" >> "$test_dir/log"; }
PROGRAM=program_stub

source usr/lib/jelastic/modules/resolver.module

function mock_curl() {
    local call_count=0
    [[ -f "$test_dir/calls" ]] && call_count=$(<"$test_dir/calls")
    call_count=$((call_count + 1))
    printf '%s' "$call_count" > "$test_dir/calls"
    sed -n "${call_count}p" "$test_dir/statuses"
}

function sleep() {
    printf '%s\n' "$1" >> "$test_dir/sleeps"
}

CURL=mock_curl

function reset_case() {
    : > "$test_dir/log"
    : > "$test_dir/sleeps"
    printf '0' > "$test_dir/calls"
    printf '%s\n' "$@" > "$test_dir/statuses"
    ZONE_NAME=app.example.test
}

function assert_equal() {
    local expected=$1 actual=$2 description=$3
    if [[ "$expected" != "$actual" ]]; then
        printf 'FAIL: %s: expected=%s actual=%s\n' "$description" "$expected" "$actual" >&2
        exit 1
    fi
}

function run_delete() {
    local status=0
    doDelUpstream || status=$?
    printf '%s' "$status"
}

reset_case 200
assert_equal 0 "$(run_delete)" "HTTP 200 succeeds"
assert_equal 1 "$(<"$test_dir/calls")" "HTTP 200 performs one request"

reset_case 409 409 202
assert_equal 0 "$(run_delete)" "HTTP 202 succeeds after conflicts"
assert_equal 3 "$(<"$test_dir/calls")" "conflicts are retried"
assert_equal 2 "$(wc -l < "$test_dir/sleeps")" "retry delays are bounded"

reset_case 409 409 409 409 409
assert_equal 1 "$(run_delete)" "persistent conflict fails"
assert_equal 5 "$(<"$test_dir/calls")" "persistent conflict stops after five attempts"

reset_case 500
assert_equal 1 "$(run_delete)" "unexpected HTTP status fails"
assert_equal 1 "$(<"$test_dir/calls")" "unexpected HTTP status is not retried"

reset_case 200
unset ZONE_NAME
assert_equal 99 "$(run_delete)" "missing zone name is rejected"
assert_equal 0 "$(<"$test_dir/calls")" "missing zone name does not call resolver"

printf 'PASS: resolver.module doDelUpstream retry contract\n'
