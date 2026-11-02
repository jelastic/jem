#!/usr/bin/env bash
set -euo pipefail

readonly root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly target="${RPM_TARGET:-el7}"
case "$target" in el7|el10) ;; *) echo 'error: unsupported RPM_TARGET' >&2; exit 2 ;; esac
command -v docker >/dev/null || { echo 'error: Docker CLI is required' >&2; exit 2; }
docker info >/dev/null

IFS=$'\t' read -r RPM_VERSION RPM_RELEASE RPM_BUILD_KIND < <("$root_dir/ci/resolve-rpm-version.sh")
export RPM_VERSION RPM_RELEASE RPM_BUILD_KIND RPM_TARGET="$target"
printf '>> Building jelastic-jem %s-%s for %s\n' "$RPM_VERSION" "$RPM_RELEASE" "$target"

image="jelastic-jem-${target}-rpm-builder:${BITBUCKET_BUILD_NUMBER:-local}"
trap 'docker image rm -f "$image" >/dev/null 2>&1 || true' EXIT
build_args=()
for proxy_var in HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy; do
    [[ -n "${!proxy_var:-}" ]] && build_args+=(--build-arg "$proxy_var")
done
docker build "${build_args[@]}" \
    -f "$root_dir/ci/Dockerfile.${target}-rpm-builder" -t "$image" "$root_dir/ci"
docker run --rm -v "$root_dir:/repo" -w /repo \
    -e RPM_VERSION -e RPM_RELEASE -e RPM_BUILD_KIND -e RPM_TARGET \
    -e "ARTIFACT_DIR=/repo/artifacts/${target}" "$image" \
    'ci/build-rpm.sh && ci/test-rpm.sh'
