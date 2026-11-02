#!/usr/bin/env bash
set -euo pipefail

readonly target="${RPM_TARGET:-}"
readonly channel_kind="${SPACEWALK_TARGET_CHANNEL_KIND:-}"
readonly server="${SPACEWALK_SERVER:-}"
readonly username="${SPACEWALK_USERNAME:-}"
readonly password="${SPACEWALK_PASSWORD:-}"
readonly expected_signing_fingerprint="${RPM_SIGNING_KEY_FINGERPRINT:-}"
readonly ssh_key_b64="${SPACEWALK_SSH_KEY_B64:-}"
readonly repo_update_host="${SPACEWALK_REPO_UPDATE_HOST:-51.75.56.196}"
readonly repo_update_port="${SPACEWALK_REPO_UPDATE_PORT:-3022}"
readonly repo_update_user="${SPACEWALK_REPO_UPDATE_USER:-root}"
readonly repo_update_command="${SPACEWALK_REPO_UPDATE_COMMAND:-/root/jenkins_update_repos.sh}"
readonly repo_dir="${CI_PROJECT_DIR:-${BITBUCKET_CLONE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
readonly branch="${CI_BRANCH_NAME:-${BITBUCKET_BRANCH:-}}"
readonly tag="${CI_TAG_NAME:-${BITBUCKET_TAG:-}}"
readonly artifact_dir="${ARTIFACT_DIR:-${repo_dir}/artifacts/${target}}"
publish_dir=""
ssh_key=""
signature_work_dir=""

cleanup() {
    [[ -z "$publish_dir" || ! -d "$publish_dir" ]] || rm -rf "$publish_dir"
    [[ -z "$ssh_key" || ! -f "$ssh_key" ]] || rm -f "$ssh_key"
    [[ -z "$signature_work_dir" || ! -d "$signature_work_dir" ]] || rm -rf "$signature_work_dir"
}
trap cleanup EXIT

for name in target channel_kind server username password ssh_key_b64 expected_signing_fingerprint; do
    [[ -n "${!name}" ]] || { printf 'error: %s is required\n' "$name" >&2; exit 2; }
done
[[ "$expected_signing_fingerprint" =~ ^[A-Fa-f0-9]{40}$ ]] || {
    echo 'error: RPM signing fingerprint must be a full 40-hex value' >&2
    exit 2
}
readonly normalized_signing_fingerprint="${expected_signing_fingerprint^^}"
case "$target" in el7|el10) ;; *) echo "error: unsupported target: $target" >&2; exit 3 ;; esac

case "$channel_kind" in
    testing)
        [[ "$branch" == version/* && -z "$tag" ]] || {
            echo 'error: testing publication requires version/X.Y.Z' >&2
            exit 3
        }
        expected_version="${branch#version/}"
        ;;
    stable)
        [[ -n "$tag" && -z "$branch" ]] || {
            echo 'error: stable publication requires an X.Y.Z tag' >&2
            exit 3
        }
        expected_version="$tag"
        ;;
    *) echo "error: unsupported channel kind: $channel_kind" >&2; exit 3 ;;
esac
[[ "$expected_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo 'error: publication version must use X.Y.Z' >&2
    exit 3
}

channel_variable="SPACEWALK_CHANNEL_${target^^}_${channel_kind^^}"
channel="${!channel_variable:-}"
[[ -n "$channel" ]] || { printf 'error: %s is required\n' "$channel_variable" >&2; exit 4; }

command -v gpg >/dev/null || { echo 'error: gpg is required' >&2; exit 5; }
command -v rpm >/dev/null || { echo 'error: rpm is required' >&2; exit 5; }
command -v rpmkeys >/dev/null || { echo 'error: rpmkeys is required' >&2; exit 5; }
command -v rhnpush >/dev/null || { echo 'error: rhnpush is required' >&2; exit 5; }
command -v ssh >/dev/null || { echo 'error: ssh is required' >&2; exit 5; }
command -v base64 >/dev/null || { echo 'error: base64 is required' >&2; exit 5; }
[[ "$channel" =~ ^[A-Za-z0-9._-]+$ ]] || { echo 'error: unsafe channel label' >&2; exit 5; }
[[ "$repo_update_host" =~ ^[A-Za-z0-9.-]+$ ]] || { echo 'error: unsafe update host' >&2; exit 5; }
[[ "$repo_update_port" =~ ^[1-9][0-9]*$ ]] || { echo 'error: invalid update port' >&2; exit 5; }
[[ "$repo_update_user" =~ ^[A-Za-z0-9._-]+$ ]] || { echo 'error: unsafe update user' >&2; exit 5; }
[[ "$repo_update_command" =~ ^/[A-Za-z0-9._/-]+$ ]] || { echo 'error: unsafe update command' >&2; exit 5; }

shopt -s nullglob
all_rpms=("${artifact_dir}"/rpms/jelastic-jem-*.rpm)
binary_rpms=()
for rpm_path in "${all_rpms[@]}"; do
    [[ "$rpm_path" == *.src.rpm ]] || binary_rpms+=("$rpm_path")
done
(( ${#binary_rpms[@]} == 1 )) || { echo 'error: expected one jelastic-jem binary RPM' >&2; exit 6; }

public_key="${artifact_dir}/RPM_SIGNING_PUBLIC_KEY.asc"
fingerprint_record="${artifact_dir}/RPM_SIGNING_KEY_FINGERPRINT"
[[ -s "$public_key" && -s "$fingerprint_record" ]] || {
    echo 'error: RPM signing trust metadata is missing' >&2
    exit 6
}
recorded_fingerprint="$(tr -d '[:space:]' < "$fingerprint_record")"
[[ "${recorded_fingerprint^^}" == "$normalized_signing_fingerprint" ]] || {
    echo 'error: RPM signing fingerprint record does not match the trusted CI fingerprint' >&2
    exit 6
}
public_fingerprint="$({
    gpg --batch --with-colons --show-keys --fingerprint "$public_key" |
        awk -F: '$1 == "pub" { primary = 1; next } primary && $1 == "fpr" { print toupper($10); exit }'
} || true)"
[[ "$public_fingerprint" == "$normalized_signing_fingerprint" ]] || {
    echo 'error: RPM signing public key does not match the trusted CI fingerprint' >&2
    exit 6
}
signature_work_dir="$(mktemp -d)"
mkdir -p "${signature_work_dir}/rpmdb"
rpmkeys --dbpath "${signature_work_dir}/rpmdb" --import "$public_key"
if ! signature_verification="$(rpmkeys --dbpath "${signature_work_dir}/rpmdb" \
    --checksig --verbose "${binary_rpms[0]}" 2>&1)"
then
    echo 'error: RPM signature verification failed' >&2
    exit 6
fi
[[ "${signature_verification^^}" == *SHA256* ]] || {
    echo 'error: RPM is not signed with an accepted SHA-256 OpenPGP signature' >&2
    exit 6
}
rpmkeys --import "$public_key"
actual_version="$(rpm -qp --qf '%{VERSION}' "${binary_rpms[0]}")"
[[ "$actual_version" == "$expected_version" ]] || {
    printf 'error: RPM version %s does not match %s\n' "$actual_version" "$expected_version" >&2
    exit 6
}

publish_dir="$(mktemp -d)"
cp -f "${binary_rpms[0]}" "$publish_dir/"
ssh_key="$(mktemp)"
printf '%s' "$ssh_key_b64" | base64 -d > "$ssh_key" || {
    echo 'error: invalid Base64 SSH key' >&2
    exit 7
}
[[ -s "$ssh_key" ]] || { echo 'error: decoded SSH key is empty' >&2; exit 7; }
chmod 0600 "$ssh_key"

printf 'Pushing jelastic-jem RPM\n  server: %s\n  channel: %s\n  source: %s\n' \
    "$server" "$channel" "$artifact_dir"
rhnpush \
    --server "$server" \
    --channel "$channel" \
    --username "$username" \
    --password "$password" \
    --new-cache --dir "$publish_dir" -v

printf 'Spacewalk push complete; regenerating mrepo for %s\n' "$channel"
ssh -i "$ssh_key" -o BatchMode=yes -o StrictHostKeyChecking=no \
    -p "$repo_update_port" "${repo_update_user}@${repo_update_host}" \
    "$repo_update_command" "$channel"
printf 'Spacewalk push and mrepo regeneration completed successfully\n'
