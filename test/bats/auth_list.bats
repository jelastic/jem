#!/usr/bin/env bats

setup() {
    TEST_ROOT="$(mktemp -d)"
    inherit() { :; }
    include() { :; }
    defineBigInline() { local name=$1; printf -v "$name" '%s' "$(cat)"; }
    PROGRAM=:
    SED=sed
    source "$BATS_TEST_DIRNAME/../../usr/lib/jelastic/modules/auth.module"
    EXPORTS_FILE="$TEST_ROOT/exports"
}

teardown() { rm -rf "$TEST_ROOT"; }

@test "auth list returns valid JSON for an NFSv3 export without fsid" {
    printf '"%s" %s\n' '/opt/nfs-share' '192.0.2.10(async,rw)' > "$EXPORTS_FILE"

    run doList

    [ "$status" -eq 0 ]
    printf '%s' "$output" | jq -e '.shares == [{name:"/opt/nfs-share", fuse:"false"}]' >/dev/null
}
