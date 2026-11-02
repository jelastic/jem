#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'error: %s\n' "$*" >&2; exit 2; }
branch="${CI_BRANCH_NAME:-${BITBUCKET_BRANCH:-}}"
tag="${CI_TAG_NAME:-${BITBUCKET_TAG:-}}"
kind="${RPM_BUILD_KIND:-auto}"

if [[ -n "$tag" ]]; then
    [[ "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'release tag must use X.Y.Z'
    version="$tag"
elif [[ "$branch" == version/* ]]; then
    version="${branch#version/}"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'version branch must use version/X.Y.Z'
else
    version='0.0.0'
fi

if [[ "$kind" == auto ]]; then
    [[ -z "$tag" ]] || fail 'tags require the manual build-rpm-release pipeline'
    [[ "$branch" == version/* ]] && kind=snapshot || kind=ci
fi

case "$kind" in
    snapshot)
        [[ -z "$tag" && "$branch" == version/* ]] || fail 'snapshot requires a version branch'
        stamp="${RPM_SNAPSHOT_DATETIME:-$(date -u +%Y%m%d%H%M%S)}"
        [[ "$stamp" =~ ^[0-9]{14}$ ]] || fail 'snapshot datetime must use UTC YYYYMMDDHHMMSS'
        release="SNAPSHOT${stamp}"
        ;;
    release)
        [[ -n "$tag" && -z "$branch" ]] || fail 'release requires an X.Y.Z tag'
        [[ "${RPM_BUILD_NUMBER:-}" =~ ^[1-9][0-9]*$ ]] || fail 'RPM_BUILD_NUMBER must be a positive integer'
        release="$RPM_BUILD_NUMBER"
        ;;
    ci)
        [[ -z "$tag" ]] || fail 'generic CI builds are not allowed from tags'
        release="${CI_BUILD_NUMBER:-${BITBUCKET_BUILD_NUMBER:-1}}"
        [[ "$release" =~ ^[1-9][0-9]*$ ]] || fail 'CI build number must be positive'
        ;;
    *) fail "unsupported RPM build kind: $kind" ;;
esac

printf '%s\t%s\t%s\n' "$version" "$release" "$kind"
