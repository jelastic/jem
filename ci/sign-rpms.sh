#!/usr/bin/env bash
# Sign release-line RPM artifacts with the explicitly trusted CI key.

set -euo pipefail

readonly repo_dir="${CI_PROJECT_DIR:-${BITBUCKET_CLONE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
readonly artifact_root="${ARTIFACT_ROOT:-${repo_dir}/artifacts}"
private_key_b64="${RPM_SIGNING_PRIVATE_KEY_B64:-}"
signing_passphrase="${RPM_SIGNING_KEY_PASSPHRASE:-}"
readonly expected_fingerprint="${RPM_SIGNING_KEY_FINGERPRINT:-}"
readonly targets="${RPM_SIGNING_TARGETS:-el7 el10}"
work_dir=""

cleanup() {
    [[ -z "$work_dir" || ! -d "$work_dir" ]] || \
        gpgconf --homedir "${work_dir}/gnupg" --kill gpg-agent >/dev/null 2>&1 || true
    [[ -z "$work_dir" || ! -d "$work_dir" ]] || rm -rf "$work_dir"
}
trap cleanup EXIT

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 2
}

[[ -n "$private_key_b64" ]] || fail 'RPM_SIGNING_PRIVATE_KEY_B64 must be configured'
[[ -n "$signing_passphrase" ]] || fail 'RPM_SIGNING_KEY_PASSPHRASE must be configured'
[[ "$expected_fingerprint" =~ ^[A-Fa-f0-9]{40}$ ]] || {
    fail 'RPM_SIGNING_KEY_FINGERPRINT must be a full 40-hex OpenPGP fingerprint'
}
readonly normalized_fingerprint="${expected_fingerprint^^}"

for command_name in base64 gpg gpgconf rpmkeys rpmsign; do
    command -v "$command_name" >/dev/null 2>&1 || fail "$command_name is required for RPM signing"
done

umask 077
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/jelastic-jem-rpm-sign.XXXXXX")"
export GNUPGHOME="${work_dir}/gnupg"
mkdir -p "$GNUPGHOME" "${work_dir}/rpmdb"
printf 'allow-preset-passphrase\n' > "${GNUPGHOME}/gpg-agent.conf"

printf '%s' "$private_key_b64" | base64 -d > "${work_dir}/private-key.asc" || {
    fail 'RPM_SIGNING_PRIVATE_KEY_B64 is not valid Base64'
}
unset RPM_SIGNING_PRIVATE_KEY_B64 RPM_SIGNING_KEY_PASSPHRASE
private_key_b64=''
[[ -s "${work_dir}/private-key.asc" ]] || fail 'decoded RPM signing key is empty'
gpg --batch --import "${work_dir}/private-key.asc" >/dev/null 2>&1 || {
    fail 'RPM signing private key import failed'
}
primary_secret_fingerprint="$({
    gpg --batch --with-colons --fingerprint --list-secret-keys |
        awk -F: '$1 == "sec" { primary = 1; next } primary && $1 == "fpr" { print toupper($10); exit }'
} || true)"
[[ "$primary_secret_fingerprint" == "$normalized_fingerprint" ]] || {
    fail 'configured fingerprint does not identify the imported primary secret key'
}
primary_secret_keygrip="$({
    gpg --batch --with-colons --with-keygrip --list-secret-keys "$normalized_fingerprint" |
        awk -F: '$1 == "sec" { primary = 1; next } primary && $1 == "grp" { print $10; exit }'
} || true)"
[[ "$primary_secret_keygrip" =~ ^[A-Fa-f0-9]{40}$ ]] || {
    fail 'imported primary secret key has no usable keygrip'
}

preset_command="$(command -v gpg-preset-passphrase || true)"
for preset_candidate in \
    "$preset_command" \
    /usr/libexec/gpg-preset-passphrase \
    /usr/lib/gnupg2/gpg-preset-passphrase \
    /usr/lib/gnupg/gpg-preset-passphrase
do
    if [[ -n "$preset_candidate" && -x "$preset_candidate" ]]; then
        preset_command="$preset_candidate"
        break
    fi
done
[[ -n "$preset_command" && -x "$preset_command" ]] || {
    fail 'gpg-preset-passphrase is required for protected CI signing keys'
}
gpgconf --homedir "$GNUPGHOME" --launch gpg-agent >/dev/null 2>&1 || {
    fail 'failed to launch the isolated GPG agent'
}
printf '%s' "$signing_passphrase" |
    "$preset_command" --homedir "$GNUPGHOME" --preset "$primary_secret_keygrip" >/dev/null 2>&1 || {
        fail 'failed to unlock the RPM signing key with RPM_SIGNING_KEY_PASSPHRASE'
    }
signing_passphrase=''

gpg --batch --armor --export "$normalized_fingerprint" > "${work_dir}/public-key.asc"
[[ -s "${work_dir}/public-key.asc" ]] || fail 'RPM signing public key export failed'
rpmkeys --dbpath "${work_dir}/rpmdb" --import "${work_dir}/public-key.asc"

signed_count=0
for target in $targets; do
    case "$target" in el7|el10) ;; *) fail "unsupported RPM signing target: ${target}" ;; esac
    target_dir="${artifact_root}/${target}"
    [[ -d "$target_dir" ]] || fail "RPM artifact directory is missing: ${target_dir}"

    shopt -s nullglob
    binary_rpms=("${target_dir}"/rpms/jelastic-jem-*.rpm)
    source_rpms=("${target_dir}"/srpms/jelastic-jem-*.src.rpm)
    shopt -u nullglob
    (( ${#binary_rpms[@]} == 1 )) || fail "expected exactly one ${target} binary RPM"
    (( ${#source_rpms[@]} == 1 )) || fail "expected exactly one ${target} source RPM"

    for rpm_path in "${binary_rpms[@]}" "${source_rpms[@]}"; do
        sign_options=(--addsign)
        [[ "$target" != el10 ]] || sign_options+=(--rpmv3)
        rpmsign "${sign_options[@]}" \
            --define "_gpg_name ${normalized_fingerprint}" \
            --define '_gpg_digest_algo sha256' \
            "$rpm_path" || {
                fail 'rpmsign failed after the protected signing key was unlocked'
            }
        if ! verification="$(rpmkeys --dbpath "${work_dir}/rpmdb" \
            --checksig --verbose "$rpm_path" 2>&1)"
        then
            fail "RPM signature verification failed: ${rpm_path}"
        fi
        [[ "${verification^^}" == *SHA256* ]] || {
            fail "RPM does not contain a SHA-256 OpenPGP signature: ${rpm_path}"
        }
        (( signed_count += 1 ))
    done

    install -m 0644 "${work_dir}/public-key.asc" "${target_dir}/RPM_SIGNING_PUBLIC_KEY.asc"
    printf '%s\n' "$normalized_fingerprint" > "${target_dir}/RPM_SIGNING_KEY_FINGERPRINT"
done

printf 'signed and verified %d RPM artifacts with key %s\n' "$signed_count" "$normalized_fingerprint"
