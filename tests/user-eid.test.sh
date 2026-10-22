#!/bin/bash

# Characterization tests for host-side user EID resolution. No containers are
# changed: vzlist and PVA paths are isolated fixtures.
set -euo pipefail

testRoot=$(mktemp -d)
trap 'rm -rf -- "$testRoot"' EXIT

include() { :; }
inherit() { :; }
isFunction() { return 1; }
log() { :; }
die() { return 1; }
PROGRAM=:
gw_boost_lib_inherit=
AWK=awk
SED=sed
GREP=grep
VZLIST=vzlist
JEM_CALLS_LOG=/dev/null
USER_OS_RELEASE="$testRoot/os-release"

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/usr/lib/jelastic/modules/user.module"

USER_PVA_ROOT="$testRoot/pva"
userPvaConfigPath() {
    printf '%s/%s\n' "$USER_PVA_ROOT" "$1"
}

assertEquals() {
    [[ "$1" == "$2" ]] || {
        printf 'expected %q, got %q\n' "$1" "$2" >&2
        exit 1
    }
}

vzlist() {
    printf '<%s>' "$@" >> "$testRoot/vzlist.calls"
    printf '\n' >> "$testRoot/vzlist.calls"
    case "$*" in
        '-a -H -o ctid,private' ) printf '%s\n' "$LEGACY_INVENTORY" ;;
        '-a -H -o ctid,uuid,private' ) printf '%s\n' "$VZ10_INVENTORY" ;;
        * ) return 1 ;;
    esac
}

legacyPrivate="$testRoot/legacy private/101"
mkdir -p "$legacyPrivate/.vza"
printf '%s\n' 'legacy-eid' > "$legacyPrivate/.vza/eid.conf"
LEGACY_INVENTORY="101 $legacyPrivate"
VZ10_INVENTORY=
printf '%s\n' 'VERSION_ID="7.9"' > "$USER_OS_RELEASE"
> "$testRoot/vzlist.calls"
assertEquals 101 "$(resolveUserContainerByEid legacy-eid)"
assertEquals '<-a><-H><-o><ctid,private>' "$(<"$testRoot/vzlist.calls")"

metadataPrivate="$testRoot/vz10 private/201"
fallbackPrivate="$testRoot/vz10 private/202"
invalidPrivate="$testRoot/vz10 private/203"
duplicatePrivate="$testRoot/vz10 private/204"
mkdir -p "$metadataPrivate/.vza" "$fallbackPrivate" "$invalidPrivate/.vza" "$duplicatePrivate"
printf '%s\n' 'metadata-eid' > "$metadataPrivate/.vza/eid.conf"
printf '%s\n' '../invalid' > "$invalidPrivate/.vza/eid.conf"
VZ10_INVENTORY="201 11111111-2222-3333-4444-555555555555 $metadataPrivate
202 aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee $fallbackPrivate
203 ffffffff-1111-2222-3333-444444444444 $invalidPrivate"
printf '%s\n' 'VERSION_ID="10"' > "$USER_OS_RELEASE"
> "$testRoot/vzlist.calls"
assertEquals 201 "$(resolveUserContainerByEid metadata-eid)"
assertEquals 202 "$(resolveUserContainerByEid aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee)"
assertEquals 203 "$(resolveUserContainerByEid ffffffff-1111-2222-3333-444444444444)"

if resolveUserContainerByEid 11111111-2222-3333-4444-555555555555 >/dev/null; then
    printf '%s\n' 'metadata did not hide the native UUID' >&2
    exit 1
fi

VZ10_INVENTORY="202 duplicate-uuid $fallbackPrivate
204 duplicate-uuid $duplicatePrivate"
if resolveUserContainerByEid duplicate-uuid >/dev/null; then
    printf '%s\n' 'duplicate UUID was not rejected' >&2
    exit 1
fi

mkdir -p "$USER_PVA_ROOT"
cat > "$USER_PVA_ROOT/pva-eid" <<'EOF'
<ns1:veid>301</ns1:veid>
EOF
> "$testRoot/vzlist.calls"
assertEquals 301 "$(resolveUserContainerByEid pva-eid)"
assertEquals '' "$(<"$testRoot/vzlist.calls")"

printf '%s\n' 'user EID tests: OK'
