#!/usr/bin/env bats

setup() {
    TEST_ROOT="$(mktemp -d)"
    export TEST_ROOT
    inherit() { :; }
    include() { :; }
    defineBigInline() { local name=$1; printf -v "$name" '%s' "$(cat)"; }
    PROGRAM=:
    AWK=awk
    VEID=999
    source "${BATS_TEST_DIRNAME}/../../usr/lib/jelastic/modules/storage.module"
}

teardown() { rm -rf "$TEST_ROOT"; }

@test "container IP discovery preserves the legacy veinfo backend" {
    isUUID() { return 1; }
    VEExecRunInteractive() { printf '%s\n' '2: venet0 inet 192.0.2.99/24 scope global'; }
    AWK="${TEST_ROOT}/awk"
    cat > "$AWK" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '192.0.2.10'
EOF
    chmod +x "$AWK"

    run getTargetIPs

    [ "$status" -eq 0 ]
    [ "$output" = '192.0.2.10' ]
}

@test "container IP discovery falls back to in-container IPv4 on VZ10" {
    isUUID() { return 1; }
    VEExecRunInteractive() { printf '%s\n' '2: venet0 inet 192.168.130.250/24 brd 192.168.130.255 scope global venet0'; }
    AWK="${TEST_ROOT}/awk"
    cat > "$AWK" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$AWK"

    run getTargetIPs

    [ "$status" -eq 0 ]
    [ "$output" = '192.168.130.250' ]
}

@test "storage source parser supports legacy and explicit NFS forms" {
    parseStorageSource '192.0.2.10:/legacy'
    [ "$mtype" = 'nfs' ]
    [ -z "$atype" ]
    [ "$sourceIP" = '192.0.2.10' ]
    [ "$sourceMount" = '/legacy' ]

    parseStorageSource 'rw:nfs://192.0.2.11:/explicit'
    [ "$mtype" = 'nfs' ]
    [ "$atype" = 'rw' ]
    [ "$sourceIP" = '192.0.2.11' ]
    [ "$sourceMount" = '/explicit' ]
}
