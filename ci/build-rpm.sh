#!/usr/bin/env bash
set -euo pipefail

readonly root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly version="${RPM_VERSION:?RPM_VERSION is required}"
readonly release="${RPM_RELEASE:?RPM_RELEASE is required}"
readonly target="${RPM_TARGET:?RPM_TARGET is required}"
readonly output_dir="${ARTIFACT_DIR:-${root_dir}/artifacts/${target}}"

case "$target" in el7|el10) ;; *) echo 'error: unsupported RPM target' >&2; exit 2 ;; esac
command -v rpmbuild >/dev/null || { echo 'error: rpmbuild is required' >&2; exit 3; }

topdir="$(mktemp -d "${TMPDIR:-/tmp}/jelastic-jem-rpmbuild.XXXXXX")"
trap 'rm -rf "$topdir"' EXIT
mkdir -p "$topdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS,stage} "$output_dir"/{rpms,srpms}
rm -f "$output_dir"/rpms/jelastic-jem-*.rpm "$output_dir"/srpms/jelastic-jem-*.src.rpm
stage="$topdir/stage/jelastic-jem-${version}"
mkdir -p "$stage"/{etc,root,usr,var}

cp -a "$root_dir/etc/jelastic" "$stage/etc/"
mkdir -p "$stage/etc/logrotate.d" "$stage/etc/profile.d" "$stage/etc/sudoers.d"
cp -a "$root_dir/etc/logrotate.d/jemlog" "$stage/etc/logrotate.d/"
cp -a "$root_dir/etc/profile.d/history.sh" "$stage/etc/profile.d/"
cp -a "$root_dir/etc/sudoers.d/jelastic" "$stage/etc/sudoers.d/"
cp -a "$root_dir/root/.vimrc" "$stage/root/"
mkdir -p "$stage/usr/bin" "$stage/usr/lib"
cp -a "$root_dir/usr/bin/jem" "$stage/usr/bin/"
cp -a "$root_dir/usr/lib/jelastic" "$stage/usr/lib/"
mkdir -p "$stage/var/lib/jelastic"
cp -a "$root_dir/var/lib/jelastic/libs" "$stage/var/lib/jelastic/"
cp -a "$root_dir/var/lib/jelastic/overrides" "$stage/var/lib/jelastic/"

(
    cd "$topdir/stage"
    find "jelastic-jem-${version}" -print0 | LC_ALL=C sort -z |
        tar --null --no-recursion --files-from=- --mtime='UTC 2000-01-01' \
            --owner=0 --group=0 --numeric-owner \
            -czf "$topdir/SOURCES/jelastic-jem-${version}.tar.gz"
)
install -m0644 "$root_dir/packaging/jelastic-jem.spec" "$topdir/SPECS/jelastic-jem.spec"
rpmbuild -ba --define "_topdir ${topdir}" --define "rpm_version ${version}" \
    --define "rpm_release ${release}" "$topdir/SPECS/jelastic-jem.spec"
cp "$topdir"/RPMS/noarch/*.rpm "$output_dir/rpms/"
cp "$topdir"/SRPMS/*.src.rpm "$output_dir/srpms/"
