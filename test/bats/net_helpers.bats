#!/usr/bin/env bats

setup() {
    TEST_ROOT="$(mktemp -d)"
    export TEST_ROOT
    inherit() { :; }
    PROGRAM=:
    source "${BATS_TEST_DIRNAME}/../../usr/lib/jelastic/libs/net.lib"
}

teardown() { rm -rf "$TEST_ROOT"; }

@test "VM IP discovery is empty when prlctl is unavailable" {
    NET_PRLCTL_COMMAND="${TEST_ROOT}/missing-prlctl"

    run dump_active_ips_vms_expanded

    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "VM IP discovery preserves the legacy prlctl backend" {
    NET_PRLCTL_COMMAND="${TEST_ROOT}/prlctl"
    cat > "$NET_PRLCTL_COMMAND" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${TEST_ROOT}/prlctl.args"
printf '%s\n' '[{"State":"running","Hardware":{"net0":{"type":"routed","ips":"192.0.2.10/32"}}}]'
EOF
    chmod +x "$NET_PRLCTL_COMMAND"

    run dump_active_ips_vms_expanded

    [ "$status" -eq 0 ]
    [ "$output" = '192.0.2.10' ]
    [ "$(cat "${TEST_ROOT}/prlctl.args")" = 'list --vmtype vm -H -i -j' ]
}
