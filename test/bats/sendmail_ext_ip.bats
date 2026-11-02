#!/usr/bin/env bats

setup() {
    TEST_ROOT="$(mktemp -d)"
    export TEST_ROOT
    inherit() { :; }
    include() { :; }
    PROGRAM=:
    AWK=awk
    IP="${TEST_ROOT}/ip"
    cat > "$IP" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$ROUTE_OUTPUT"
EOF
    chmod +x "$IP"
    source "${BATS_TEST_DIRNAME}/../../usr/lib/jelastic/libs/sendmailextip.lib"
}

teardown() { rm -rf "$TEST_ROOT"; }

@test "sendmail source IP parser supports the VZ7 route format" {
    export ROUTE_OUTPUT='1.0.0.0 dev venet0 src 192.168.130.10'

    run getSendmailRouteSourceIp

    [ "$status" -eq 0 ]
    [ "$output" = '192.168.130.10' ]
}

@test "sendmail source IP parser supports the VZ10 uid suffix" {
    export ROUTE_OUTPUT='1.0.0.0 dev venet0 src 192.168.130.20 uid 0'

    run getSendmailRouteSourceIp

    [ "$status" -eq 0 ]
    [ "$output" = '192.168.130.20' ]
}

@test "sendmail source IP parser ignores the VZ10 cache line" {
    export ROUTE_OUTPUT=$'1.0.0.0 dev venet0 src 192.168.130.30 uid 0\n    cache'

    run getSendmailRouteSourceIp

    [ "$status" -eq 0 ]
    [ "$output" = '192.168.130.30' ]
}
