#!/usr/bin/env bash
set -euo pipefail

readonly repo_dir="${CI_PROJECT_DIR:-${BITBUCKET_CLONE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
readonly target="${RPM_TARGET:-}"
readonly channel_kind="${SPACEWALK_TARGET_CHANNEL_KIND:-}"
readonly push_image="${SPACEWALK_PUSH_IMAGE:-rockylinux:8}"

case "$target" in el7|el10) ;; *) echo 'error: RPM_TARGET must be el7 or el10' >&2; exit 2 ;; esac
case "$channel_kind" in testing|stable) ;; *) echo 'error: channel kind must be testing or stable' >&2; exit 2 ;; esac
command -v docker >/dev/null || { echo 'error: Docker CLI is unavailable' >&2; exit 2; }

for name in SPACEWALK_SERVER SPACEWALK_USERNAME SPACEWALK_PASSWORD SPACEWALK_SSH_KEY_B64; do
    [[ -n "${!name:-}" ]] || { printf 'error: %s must be configured\n' "$name" >&2; exit 3; }
done

run_env=(
    --env RPM_TARGET
    --env SPACEWALK_TARGET_CHANNEL_KIND
    --env SPACEWALK_SERVER
    --env SPACEWALK_USERNAME
    --env SPACEWALK_PASSWORD
    --env SPACEWALK_SSH_KEY_B64
)
for name in \
    RPM_SIGNING_KEY_FINGERPRINT \
    SPACEWALK_CHANNEL_EL7_TESTING SPACEWALK_CHANNEL_EL7_STABLE \
    SPACEWALK_CHANNEL_EL10_TESTING SPACEWALK_CHANNEL_EL10_STABLE \
    SPACEWALK_REPO_UPDATE_HOST SPACEWALK_REPO_UPDATE_PORT \
    SPACEWALK_REPO_UPDATE_USER SPACEWALK_REPO_UPDATE_COMMAND \
    CI_BRANCH_NAME CI_TAG_NAME BITBUCKET_BRANCH BITBUCKET_TAG
do
    [[ -z "${!name:-}" ]] || run_env+=(--env "$name")
done
for name in HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy; do
    [[ -z "${!name:-}" ]] || run_env+=(--env "$name")
done

export RPM_TARGET SPACEWALK_TARGET_CHANNEL_KIND
printf '>> Publishing jelastic-jem %s RPM to Spacewalk %s\n' "$target" "$channel_kind"
docker pull "$push_image"
docker run --rm \
    --network host \
    --volume "${repo_dir}:/repo:ro" \
    --workdir /repo \
    "${run_env[@]}" \
    "$push_image" /bin/bash -lc '
        set -euo pipefail
        dnf -y install ca-certificates gnupg2 rpm openssh-clients
        dnf -y install rhnpush || dnf -y install python3-rhnpush
        bash scripts/push-jelastic-jem-to-spacewalk.sh
    '
