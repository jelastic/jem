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

@test "auth list ignores empty and comment-only exports lines" {
    printf '\n# managed by JEM\n' > "$EXPORTS_FILE"

    run doList

    [ "$status" -eq 0 ]
    printf '%s' "$output" | jq -e '.shares == []' >/dev/null
}

@test "auth setup command reloads an existing unfsd process" {
    grep -Fq 'if pgrep unfsd >/dev/null' <<< "$_INSTALLUNFSDCMD"
    grep -Fq 'kill -HUP $(pidof -s unfsd)' <<< "$_INSTALLUNFSDCMD"
}

@test "AlmaLinux auth setup installs showmount through nfs-utils" {
    grep -Fq 'addPackages="libtirpc nfs-utils"' "$BATS_TEST_DIRNAME/../../usr/lib/jelastic/modules/auth.module"
}

@test "auth firewall inserts NFS allow rules before terminal firewall rules" {
    grep -Fq '$IPT -I INPUT 1 -p tcp -m multiport --dports 111,2049 -s $nfsip -j ACCEPT' "$BATS_TEST_DIRNAME/../../usr/lib/jelastic/modules/auth.module"
    grep -Fq '$IPT -D INPUT -p tcp -m multiport --dports 111,2049 -s $nfsip -j ACCEPT 2>/dev/null || true' "$BATS_TEST_DIRNAME/../../usr/lib/jelastic/modules/auth.module"
}

@test "auth nft firewall uses the filter table and inserts source-specific NFS allows" {
    grep -Fq 'nft insert rule $FW_DEFAULT_TABLE_TYPE $FW_FILTER_TABLE_NAME $FW_FILTER_INPUT_CHAIN ip protocol tcp ip saddr $nfsip' "$BATS_TEST_DIRNAME/../../usr/lib/jelastic/modules/auth.module"
    ! grep -Fq 'nft add rule $FW_DEFAULT_TABLE_TYPE $FW_TABLE_NAME $FW_FILTER_INPUT_CHAIN' "$BATS_TEST_DIRNAME/../../usr/lib/jelastic/modules/auth.module"
}

@test "auth nft firewall defines unfsd and rpcbind ports" {
    grep -Fq 'local NFSPort="2049"' "$BATS_TEST_DIRNAME/../../usr/lib/jelastic/modules/auth.module"
    grep -Fq 'local RPCPort="111"' "$BATS_TEST_DIRNAME/../../usr/lib/jelastic/modules/auth.module"
}

@test "auth clean defaults to native IP cleanup" {
    grep -Fq '[[ -z "$ATYPE" ]] && ATYPE="ip"' "$BATS_TEST_DIRNAME/../../usr/lib/jelastic/modules/auth.module"
}
