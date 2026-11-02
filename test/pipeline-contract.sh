#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tests=0
ok() { tests=$((tests + 1)); printf 'ok %d - %s\n' "$tests" "$1"; }

record="$(env -u BITBUCKET_TAG -u CI_TAG_NAME \
    CI_BRANCH_NAME=version/9.0.1 RPM_SNAPSHOT_DATETIME=20261102130000 \
    "$root/ci/resolve-rpm-version.sh")"
[[ "$record" == $'9.0.1\tSNAPSHOT20261102130000\tsnapshot' ]]
ok 'version branch resolves snapshot coordinates'

record="$(env -u BITBUCKET_BRANCH -u CI_BRANCH_NAME \
    CI_TAG_NAME=9.0.1 RPM_BUILD_KIND=release RPM_BUILD_NUMBER=7 \
    "$root/ci/resolve-rpm-version.sh")"
[[ "$record" == $'9.0.1\t7\trelease' ]]
ok 'release tag resolves stable coordinates'

grep -Fq 'AutoReq:        no' "$root/packaging/jelastic-jem.spec"
ok 'legacy dependency set is protected from automatic additions'
grep -Fq '%global __brp_mangle_shebangs %{nil}' "$root/packaging/jelastic-jem.spec"
ok 'EL10 cannot rewrite source shebangs'
grep -Fq -- "--define '_gpg_digest_algo sha256'" "$root/ci/sign-rpms.sh"
ok 'new RPM signatures require SHA-256'
grep -Fq 'sign_options+=(--rpmv3)' "$root/ci/sign-rpms.sh"
ok 'EL10 artifacts retain the VZ7-compatible signature layout'
! grep -R -Fq -- '--nosig' "$root/ci" "$root/scripts"
ok 'publication never bypasses signatures'
grep -Fq '"$repo_update_command" "$channel"' "$root/scripts/push-jelastic-jem-to-spacewalk.sh"
ok 'successful publication regenerates only the selected mrepo channel'

while IFS= read -r script; do bash -n "$script"; done < <(
    find "$root/ci" "$root/scripts" "$root/test" -type f -name '*.sh' | LC_ALL=C sort
)
ok 'delivery scripts pass syntax validation'

"$root/test/publication-contract.sh"
ok 'signing and publication behavior passes mocked integration tests'

printf '1..%d\n' "$tests"
