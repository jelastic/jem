#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
tests=0

ok() {
    tests=$((tests + 1))
    printf 'ok %d - %s\n' "$tests" "$1"
}

fail() {
    printf 'not ok %d - %s\n' "$((tests + 1))" "$1" >&2
    exit 1
}

assert_log() {
    grep -Fq -- "$1" "$MOCK_TOOL_LOG" || fail "$2"
    ok "$2"
}

readonly signing_fingerprint='0123456789ABCDEF0123456789ABCDEF01234567'
mkdir -p "$fixture/bin" "$fixture/publish/rpms"
: > "$fixture/publish/rpms/jelastic-jem-9.0.1-SNAPSHOT20260916120000.noarch.rpm"
printf 'public key fixture\n' > "$fixture/publish/RPM_SIGNING_PUBLIC_KEY.asc"
printf '%s\n' "$signing_fingerprint" > "$fixture/publish/RPM_SIGNING_KEY_FINGERPRINT"
export MOCK_TOOL_LOG="$fixture/tools.log"

cat > "$fixture/bin/rpm" <<'EOF'
#!/usr/bin/env bash
printf 'rpm <%s>\n' "$*" >> "$MOCK_TOOL_LOG"
[[ "$1" != -qp ]] || printf '%s' "${MOCK_RPM_VERSION:-9.0.1}"
EOF
cat > "$fixture/bin/gpg" <<'EOF'
#!/usr/bin/env bash
printf 'gpg <%s>\n' "$*" >> "$MOCK_TOOL_LOG"
if [[ " $* " == *' --show-keys '* ]]; then
    printf 'pub:-:2048:1:01234567:0:0::::::\n'
    printf 'fpr:::::::::%s:\n' "${MOCK_PUBLIC_FINGERPRINT:-$RPM_SIGNING_KEY_FINGERPRINT}"
    exit 0
fi
exit 64
EOF
cat > "$fixture/bin/rpmkeys" <<'EOF'
#!/usr/bin/env bash
printf 'rpmkeys <%s>\n' "$*" >> "$MOCK_TOOL_LOG"
[[ " $* " != *' --import '* ]] || exit 0
if [[ " $* " == *' --checksig '* ]]; then
    printf '%s\n' "${MOCK_RPMKEYS_OUTPUT:-Header V4 RSA/SHA256 Signature, key ID 01234567: OK}"
    exit "${MOCK_RPMKEYS_STATUS:-0}"
fi
exit 64
EOF
cat > "$fixture/bin/rhnpush" <<'EOF'
#!/usr/bin/env bash
printf 'rhnpush <%s>\n' "$*" >> "$MOCK_TOOL_LOG"
exit "${MOCK_RHNPUSH_STATUS:-0}"
EOF
cat > "$fixture/bin/ssh" <<'EOF'
#!/usr/bin/env bash
printf 'ssh <%s>\n' "$*" >> "$MOCK_TOOL_LOG"
EOF
chmod 0755 "$fixture/bin/"*

run_publish() {
    PATH="$fixture/bin:/usr/bin:/bin" \
    RPM_TARGET=el10 \
    SPACEWALK_TARGET_CHANNEL_KIND=testing \
    SPACEWALK_SERVER=spacewalk.example.test \
    SPACEWALK_USERNAME=test-user \
    SPACEWALK_PASSWORD=test-password \
    SPACEWALK_SSH_KEY_B64=a2V5 \
    RPM_SIGNING_KEY_FINGERPRINT="$signing_fingerprint" \
    SPACEWALK_CHANNEL_EL10_TESTING=jelastic-app-9.0-1 \
    SPACEWALK_REPO_UPDATE_HOST=mrepo.example.test \
    SPACEWALK_REPO_UPDATE_PORT=3022 \
    SPACEWALK_REPO_UPDATE_USER=root \
    SPACEWALK_REPO_UPDATE_COMMAND=/root/update-repos.sh \
    BITBUCKET_BRANCH=version/9.0.1 \
    BITBUCKET_TAG= \
    ARTIFACT_DIR="$fixture/publish" \
    "$root/scripts/push-jelastic-jem-to-spacewalk.sh"
}

run_publish >/dev/null
assert_log '--channel jelastic-app-9.0-1' 'EL10 testing publication selects its configured channel'
assert_log '/root/update-repos.sh jelastic-app-9.0-1' 'successful upload regenerates the selected channel'
assert_log 'rpmkeys <--import' 'publisher imports the validated key before upload'

: > "$MOCK_TOOL_LOG"
if MOCK_RHNPUSH_STATUS=1 run_publish >/dev/null 2>&1; then
    fail 'failed upload fails publication'
fi
ok 'failed upload fails publication'
if grep -q '^ssh ' "$MOCK_TOOL_LOG"; then
    fail 'failed upload does not regenerate mrepo'
fi
ok 'failed upload does not regenerate mrepo'

mv "$fixture/publish/RPM_SIGNING_PUBLIC_KEY.asc" "$fixture/public-key.saved"
if run_publish >/dev/null 2>&1; then
    fail 'publication rejects missing signing trust metadata'
fi
ok 'publication rejects missing signing trust metadata'
mv "$fixture/public-key.saved" "$fixture/publish/RPM_SIGNING_PUBLIC_KEY.asc"

if MOCK_PUBLIC_FINGERPRINT=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA \
    run_publish >/dev/null 2>&1
then
    fail 'publication rejects a mismatching public key'
fi
ok 'publication rejects a mismatching public key'

if MOCK_RPMKEYS_OUTPUT='Header V4 RSA/SHA1 Signature, key ID 01234567: OK' \
    run_publish >/dev/null 2>&1
then
    fail 'publication rejects a SHA-1 RPM signature'
fi
ok 'publication rejects a SHA-1 RPM signature'

if MOCK_RPMKEYS_STATUS=1 run_publish >/dev/null 2>&1; then
    fail 'publication rejects an invalid RPM signature'
fi
ok 'publication rejects an invalid RPM signature'

if MOCK_RPM_VERSION=9.0.2 run_publish >/dev/null 2>&1; then
    fail 'publication rejects an RPM from a different release line'
fi
ok 'publication rejects an RPM from a different release line'

rm -f "$fixture/bin/"*
readonly keygrip='89ABCDEF0123456789ABCDEF0123456789ABCDEF'
readonly passphrase='test-only-passphrase'
for target in el7 el10; do
    mkdir -p "$fixture/sign/$target/rpms" "$fixture/sign/$target/srpms"
    : > "$fixture/sign/$target/rpms/jelastic-jem-9.0.1-1.noarch.rpm"
    : > "$fixture/sign/$target/srpms/jelastic-jem-9.0.1-1.src.rpm"
done

cat > "$fixture/bin/base64" <<'EOF'
#!/usr/bin/env bash
cat
EOF
cat > "$fixture/bin/gpg" <<'EOF'
#!/usr/bin/env bash
printf 'gpg <%s>\n' "$*" >> "$MOCK_TOOL_LOG"
if [[ " $* " == *' --import '* ]]; then exit 0; fi
if [[ " $* " == *' --list-secret-keys '* ]]; then
    printf 'sec:-:2048:1:01234567:0:0::::::\n'
    printf 'fpr:::::::::%s:\n' "${MOCK_SECRET_FINGERPRINT:-$RPM_SIGNING_KEY_FINGERPRINT}"
    printf 'grp:::::::::%s:\n' "$TEST_SIGNING_KEYGRIP"
    exit 0
fi
if [[ " $* " == *' --export '* ]]; then printf 'public key fixture\n'; exit 0; fi
exit 64
EOF
cat > "$fixture/bin/gpgconf" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$fixture/bin/gpg-preset-passphrase" <<'EOF'
#!/usr/bin/env bash
IFS= read -r supplied || true
[[ "$supplied" == "$TEST_SIGNING_PASSPHRASE" ]] || exit 62
[[ "$*" == *"$TEST_SIGNING_KEYGRIP"* ]] || exit 63
exit "${MOCK_PRESET_STATUS:-0}"
EOF
cat > "$fixture/bin/rpmsign" <<'EOF'
#!/usr/bin/env bash
[[ -z "${RPM_SIGNING_KEY_PASSPHRASE+x}" ]] || exit 65
printf 'rpmsign <%s>\n' "$*" >> "$MOCK_TOOL_LOG"
EOF
cat > "$fixture/bin/rpmkeys" <<'EOF'
#!/usr/bin/env bash
printf 'rpmkeys <%s>\n' "$*" >> "$MOCK_TOOL_LOG"
[[ " $* " != *' --import '* ]] || exit 0
if [[ " $* " == *' --checksig '* ]]; then
    printf '%s\n' "${MOCK_RPMKEYS_OUTPUT:-Header V4 RSA/SHA256 Signature, key ID 01234567: OK}"
    exit "${MOCK_RPMKEYS_STATUS:-0}"
fi
exit 64
EOF
chmod 0755 "$fixture/bin/"*
export TEST_SIGNING_KEYGRIP="$keygrip" TEST_SIGNING_PASSPHRASE="$passphrase"

run_sign() {
    PATH="$fixture/bin:/usr/bin:/bin" \
    ARTIFACT_ROOT="$fixture/sign" \
    RPM_SIGNING_PRIVATE_KEY_B64=private-key-fixture \
    RPM_SIGNING_KEY_FINGERPRINT="$signing_fingerprint" \
    RPM_SIGNING_KEY_PASSPHRASE="$passphrase" \
    "$root/ci/sign-rpms.sh"
}

: > "$MOCK_TOOL_LOG"
run_sign >/dev/null
[[ "$(grep -c '^rpmsign ' "$MOCK_TOOL_LOG")" == 4 ]] || fail 'signer covers binary and source RPMs for both targets'
ok 'signer covers binary and source RPMs for both targets'
[[ "$(grep -c -- '--rpmv3' "$MOCK_TOOL_LOG")" == 2 ]] || fail 'EL10 uses two legacy-compatible signatures'
ok 'EL10 uses two legacy-compatible signatures'
if grep 'jelastic-jem-rpm-sign\|/el7/' "$MOCK_TOOL_LOG" | grep -q -- '--rpmv3'; then
    fail 'EL7 signature layout remains unchanged'
fi
ok 'EL7 signature layout remains unchanged'

if env -u RPM_SIGNING_KEY_PASSPHRASE \
    PATH="$fixture/bin:/usr/bin:/bin" ARTIFACT_ROOT="$fixture/sign" \
    RPM_SIGNING_PRIVATE_KEY_B64=private-key-fixture \
    RPM_SIGNING_KEY_FINGERPRINT="$signing_fingerprint" \
    "$root/ci/sign-rpms.sh" >/dev/null 2>&1
then
    fail 'signer requires a protected-key passphrase'
fi
ok 'signer requires a protected-key passphrase'

if MOCK_PRESET_STATUS=1 run_sign >/dev/null 2>&1; then
    fail 'signer rejects a passphrase that cannot unlock the key'
fi
ok 'signer rejects a passphrase that cannot unlock the key'

if MOCK_SECRET_FINGERPRINT=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA \
    run_sign >/dev/null 2>&1
then
    fail 'signer rejects a mismatching primary key'
fi
ok 'signer rejects a mismatching primary key'

if MOCK_RPMKEYS_OUTPUT='Header V4 RSA/SHA1 Signature, key ID 01234567: OK' \
    run_sign >/dev/null 2>&1
then
    fail 'signer rejects a SHA-1 RPM signature'
fi
ok 'signer rejects a SHA-1 RPM signature'

printf '1..%d\n' "$tests"
