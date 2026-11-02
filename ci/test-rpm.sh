#!/usr/bin/env bash
set -euo pipefail

readonly root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly target="${RPM_TARGET:?RPM_TARGET is required}"
readonly artifact_dir="${ARTIFACT_DIR:-${root_dir}/artifacts/${target}}"
case "$target" in el7|el10) ;; *) echo 'error: unsupported RPM target' >&2; exit 2 ;; esac

shopt -s nullglob
rpms=("$artifact_dir"/rpms/jelastic-jem-*.noarch.rpm)
(( ${#rpms[@]} == 1 )) || { echo 'error: expected exactly one binary RPM' >&2; exit 1; }
rpm_path="${rpms[0]}"

metadata="$(rpm -qp --qf '%{NAME}\t%{VERSION}\t%{RELEASE}\t%{ARCH}\n' "$rpm_path")"
IFS=$'\t' read -r name version release arch <<< "$metadata"
[[ "$name" == jelastic-jem && "$version" == "${RPM_VERSION:?RPM_VERSION is required}" && "$arch" == noarch ]] || {
    echo "error: unexpected RPM metadata: $metadata" >&2; exit 1;
}
[[ "$release" == "${RPM_RELEASE:?RPM_RELEASE is required}" || "$release" == "$RPM_RELEASE".* ]] || {
    echo 'error: unexpected RPM release' >&2; exit 1;
}

expected_files="$(mktemp)"
actual_files="$(mktemp)"
dump_file="$(mktemp)"
trap 'rm -f "$expected_files" "$actual_files" "$dump_file"' EXIT
{
    printf '%s\n' \
        /etc/jelastic/export.conf /etc/jelastic/jelastic.conf /etc/jelastic/timeouts.conf \
        /etc/logrotate.d/jemlog /etc/profile.d /etc/profile.d/history.sh \
        /etc/sudoers.d /etc/sudoers.d/jelastic /root/.vimrc /usr/bin/jem \
        /usr/lib/jelastic /usr/lib/jelastic/libs /usr/lib/jelastic/modules \
        /usr/lib/jelastic/tpls /var/lib/jelastic/overrides
    find "$root_dir/usr/lib/jelastic/libs" -type f -printf '/usr/lib/jelastic/libs/%f\n'
    find "$root_dir/usr/lib/jelastic/modules" -type f -printf '/usr/lib/jelastic/modules/%f\n'
    find "$root_dir/usr/lib/jelastic/tpls" -type f -printf '/usr/lib/jelastic/tpls/%f\n'
    find "$root_dir/var/lib/jelastic/libs" -type f -printf '/var/lib/jelastic/libs/%f\n'
    find "$root_dir/var/lib/jelastic/overrides" -type f -printf '/var/lib/jelastic/overrides/%f\n'
} | LC_ALL=C sort -u > "$expected_files"
rpm -qpl "$rpm_path" | LC_ALL=C sort -u > "$actual_files"
diff -u "$expected_files" "$actual_files"
[[ "$(wc -l < "$actual_files")" -eq 123 ]] || { echo 'error: RPM payload path count changed' >&2; exit 1; }

rpm -qpl --dump "$rpm_path" > "$dump_file"
while read -r path _size _mtime digest mode _rest; do
    [[ "$mode" == 010* ]] || continue
    source_path="${root_dir}${path}"
    [[ -f "$source_path" ]] || {
        printf 'error: no source counterpart for packaged file %s\n' "$path" >&2
        exit 1
    }
    source_digest="$(sha256sum "$source_path" | awk '{ print $1 }')"
    [[ "$digest" == "$source_digest" ]] || {
        printf 'error: packaged content differs from source for %s\n' "$path" >&2
        exit 1
    }
done < "$dump_file"

assert_mode() {
    local path="$1" expected="$2" actual
    actual="$(awk -v path="$path" '$1 == path { print substr($5, length($5) - 3); exit }' "$dump_file")"
    [[ "$actual" == "$expected" ]] || {
        printf 'error: %s has mode %s, expected %s\n' "$path" "${actual:-missing}" "$expected" >&2
        exit 1
    }
}
while IFS= read -r path; do assert_mode "$path" 0400; done < <(
    find "$root_dir/usr/lib/jelastic/libs" -type f -printf '/usr/lib/jelastic/libs/%f\n'
    find "$root_dir/usr/lib/jelastic/modules" -type f -printf '/usr/lib/jelastic/modules/%f\n'
    find "$root_dir/usr/lib/jelastic/tpls" -type f -printf '/usr/lib/jelastic/tpls/%f\n'
)
while IFS= read -r path; do assert_mode "$path" 0755; done < <(
    find "$root_dir/var/lib/jelastic/libs" -type f -printf '/var/lib/jelastic/libs/%f\n'
    find "$root_dir/var/lib/jelastic/overrides" -type f -printf '/var/lib/jelastic/overrides/%f\n'
)
assert_mode /usr/lib/jelastic 0500
assert_mode /usr/lib/jelastic/libs 0500
assert_mode /usr/lib/jelastic/modules 0500
assert_mode /usr/lib/jelastic/tpls 0500
assert_mode /etc/sudoers.d/jelastic 0750
assert_mode /usr/bin/jem 0755
assert_mode /root/.vimrc 0700

requires="$(rpm -qpR "$rpm_path")"
for requirement in /bin/sh bind-utils logrotate net-tools policycoreutils rpcbind; do
    grep -qx "$requirement" <<< "$requires"
done
actual_runtime_requires="$(grep -v '^rpmlib(' <<< "$requires" | LC_ALL=C sort -u)"
expected_runtime_requires="$(printf '%s\n' /bin/sh bind-utils logrotate net-tools policycoreutils rpcbind | LC_ALL=C sort)"
[[ "$actual_runtime_requires" == "$expected_runtime_requires" ]] || {
    printf 'error: runtime dependency set differs from legacy contract\n%s\n' "$actual_runtime_requires" >&2
    exit 1
}
[[ "$(rpm -qp --provides "$rpm_path" | grep -c '^jelastic-jem = ')" -eq 1 ]]
[[ -z "$(rpm -qp --configfiles "$rpm_path")" ]] || {
    echo 'error: parity package must not introduce config-file upgrade semantics' >&2; exit 1;
}

scripts="$(rpm -qp --scripts "$rpm_path")"
grep -Fq 'postinstall scriptlet (using /bin/sh):' <<< "$scripts"
grep -Fq 'chmod 511 /usr/bin/jem' <<< "$scripts"
grep -Fq 'ln -s /var/lib/jelastic/libs/envinfo.lib /usr/lib/jelastic/libs/envinfo.lib' <<< "$scripts"
grep -Fq 'ln -s /var/lib/jelastic/libs/cartridge-sdk.lib /usr/lib/jelastic/libs/cartridge-sdk.lib' <<< "$scripts"
grep -Fq 'Banner /etc/jmotd' <<< "$scripts"

for forbidden in /etc/jelastic.conf /usr/bin/jem_debug /var/lib/jelastic/customizations/override_deploy.lib.example; do
    ! grep -Fxq "$forbidden" "$actual_files" || { echo "error: excluded path packaged: $forbidden" >&2; exit 1; }
done

printf 'RPM validation passed: %s\n' "$rpm_path"
