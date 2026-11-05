#!/bin/bash

set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly INVOCATION_LIB="${ROOT_DIR}/usr/lib/jelastic/libs/invocation.lib"
readonly LOGROTATE_CONFIG="${ROOT_DIR}/etc/logrotate.d/jemlog"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/jem-invocation-test.XXXXXX")"
trap 'rm -rf -- "$work_dir"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_mode() {
    local expected="$1"
    local path="$2"
    local actual

    actual="$(stat -c '%a' "$path")"
    [[ "$actual" == "$expected" ]] || fail "expected mode $expected for $path, got $actual"
}

# A regular container user must be able to append to the shared log without
# owning it and without trying to change its permissions.
non_root_log="${work_dir}/non-root.log"
: > "$non_root_log"
/bin/chmod 0666 "$non_root_log"
(
    source "$INVOCATION_LIB"
    id() {
        [[ "${1:-}" == -u ]] || return 2
        printf '1000\n'
    }
    chmod() {
        printf '%s\n' "$*" >> "${work_dir}/unexpected-chmod.calls"
        return 91
    }

    jemLogInvocation "$non_root_log" 101 service reload
    jemLogInvocation "$non_root_log" 102 agent setup --password secret-value
)

[[ ! -e "${work_dir}/unexpected-chmod.calls" ]] || \
    fail 'non-root invocation attempted to chmod the shared log'
assert_mode 666 "$non_root_log"
grep -Fq '[PID: 101] service reload' "$non_root_log" || \
    fail 'service invocation was not logged'
grep -Fq '[PID: 102] agent setup --password [REDACTED]' "$non_root_log" || \
    fail 'agent password was not redacted'
if grep -Fq 'secret-value' "$non_root_log"; then
    fail 'agent password leaked into the shared log'
fi

# A privileged invocation owns enforcement of the world-writable mode.
root_log="${work_dir}/root.log"
: > "$root_log"
/bin/chmod 0600 "$root_log"
(
    source "$INVOCATION_LIB"
    id() {
        [[ "${1:-}" == -u ]] || return 2
        printf '0\n'
    }
    chmod() {
        printf '%s\n' "$*" >> "${work_dir}/root-chmod.calls"
        /bin/chmod "$@"
    }

    jemLogInvocation "$root_log" 103 agent getInfo --ctid 101
)

grep -Fxq "0666 $root_log" "${work_dir}/root-chmod.calls" || \
    fail 'root invocation did not enforce mode 0666'
assert_mode 666 "$root_log"

grep -Eq '^[[:space:]]*create[[:space:]]+0666[[:space:]]+root[[:space:]]+root([[:space:]]|$)' \
    "$LOGROTATE_CONFIG" || fail 'logrotate does not recreate jem.log with mode 0666'

printf 'invocation logging contract tests passed\n'
