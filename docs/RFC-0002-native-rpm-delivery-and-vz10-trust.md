# RFC-0002: Native JEM Core RPM Delivery and VZ10 Trust

- Status: Proposed; CI execution backend decision required
- Date: 2026-09-16
- Source branch: `version/9.0.1`
- Source baseline: `41911f3`
- Package: `jelastic-jem`
- Intended targets: EL7 and EL10, noarch

## 1. Purpose

JEM Core is now developed in its own Git repository, but the repository owns
neither an RPM specification nor a visible build/publication pipeline. The
available `9.0.1` RPM was produced by an external Jenkins environment and is
signed with RSA/SHA1. VZ10 rejects that signature under its default crypto
policy. The package was installable during functional validation only with a
one-shot `--nogpgcheck` exception.

This RFC defines the evidence and gates required to move JEM Core to an
auditable native RPM pipeline using the same trust contract as JEM-HN and
`resolvepath`. It does not authorize an RPM build or publication.

## 2. Runtime Evidence

Both VZ10 validation nodes contain the same package:

```text
jelastic-jem-9.0.1-SNAPSHOT20260914134916.noarch
Signature: RSA/SHA1, key ID 7ee32794b18af9e3
Installed size: 702264 bytes
Source RPM: jelastic-jem-9.0.1-SNAPSHOT20260914134916.src.rpm
Build host: node265756-jenkins.madrid.central.jelastic.team
```

RPM verification on both nodes reports that SHA1 does not satisfy the VZ10
collision-resistance policy. This is a delivery defect, not a JEM runtime
failure.

The runtime dependencies are:

- `/bin/sh`;
- `bind-utils`;
- `logrotate`;
- `net-tools`;
- `policycoreutils`;
- `rpcbind`.

No installed file is marked as `%config` or `%doc` in the legacy package.
Changing that behavior is outside the first parity candidate because it changes
upgrade semantics.

## 3. Observed Payload Contract

The package owns 123 entries: 116 non-directory payload entries and seven
directories. Every non-directory path has an exact source counterpart in the
Git tree. The only source paths under package-like roots that are deliberately
absent from the RPM are:

- `/etc/jelastic.conf`;
- `/usr/bin/jem_debug`;
- `/var/lib/jelastic/customizations/override_deploy.lib.example`.

The owned directories and modes are:

| Path | Mode |
| --- | --- |
| `/etc/profile.d` | `0755` |
| `/etc/sudoers.d` | `0750` |
| `/usr/lib/jelastic` | `0500` |
| `/usr/lib/jelastic/libs` | `0500` |
| `/usr/lib/jelastic/modules` | `0500` |
| `/usr/lib/jelastic/tpls` | `0500` |
| `/var/lib/jelastic/overrides` | `0755` |

All 102 files under `/usr/lib/jelastic/{libs,modules,tpls}` use mode `0400`.
The remaining file modes are:

- `0644`: the three `/etc/jelastic/*.conf` files and `jemlog` logrotate file;
- `0700`: `/root/.vimrc`;
- `0750`: `/etc/sudoers.d/jelastic`;
- `0755`: `/etc/profile.d/history.sh`, `/usr/bin/jem`, three files below
  `/var/lib/jelastic/libs`, and three override examples.

JEM-HN deliberately does not own the shared `/usr/lib/jelastic` directory
hierarchy. JEM Core remains its single package owner, preserving the conflict
resolution implemented in the JEM-HN native spec.

## 4. Scriptlet Contract

The legacy package has one `%post` scriptlet. It currently:

1. ensures `/var/lib/jelastic` exists;
2. disables the legacy sudo `requiretty` default when present;
3. replaces the root `LC_ALL` export with `en_US.UTF-8`;
4. configures `/etc/jmotd` as the SSH banner;
5. creates `/etc/exports` with mode `0666` when absent;
6. applies the historical JEM and sudoers modes;
7. makes `/var/lib/jelastic/libs/gitssh.sh` executable;
8. replaces two packaged library paths with symlinks to their `/var` copies;
9. writes either an empty or application-node JEM banner depending on whether
   `docker.module` is installed.

The first native candidate must either preserve this scriptlet byte-for-byte
or make every intentional difference explicit in a separate, runtime-tested
RFC. Silent modernization during build migration is not acceptable.

## 5. Version and Artifact Contract

The repository should use the established shared resolver contract:

- `version/X.Y.Z` produces `X.Y.Z-SNAPSHOT<UTC YYYYMMDDHHMMSS>`;
- an `X.Y.Z` tag plus a manually supplied positive build number produces
  `X.Y.Z-<buildnumber>`;
- all other refs produce non-publishable `0.0.0-<CI build number>` artifacts.

EL7 and EL10 builders must independently validate the same noarch payload.
Artifacts must remain in separate target roots so the packaged metadata and
target toolchains remain observable even when their file content is equal.

## 6. Signing and Publication Contract

The JEM Core pipeline must use the same two inputs as JEM-HN and `resolvepath`:

- secured `RPM_SIGNING_PRIVATE_KEY_B64`;
- non-secret full primary-key fingerprint
  `RPM_SIGNING_KEY_FINGERPRINT`.

Only version-branch and manual release pipelines may access the private key.
The signing step must use an ephemeral OpenPGP home, require the primary secret
key to match the configured fingerprint, force a SHA-256 RPM signature digest,
and verify every binary RPM and SRPM in an isolated RPM database. The publisher
must independently validate the exported public key, fingerprint, digest, and
signature and must not use `rhnpush --nosig`.

The matching public key must be deployed to Spacewalk/mrepo metadata and the
normal VZ7/VZ10 repository trust path. A successful pipeline-side signature
check alone does not prove that clients trust the repository.

## 7. CI Execution Backend Decision

The source repository contains no pipeline definition, package spec, or pointer
to the external Jenkins job that produced the observed RPM. Two implementation
paths are possible:

### Option A: repository-owned GitHub Actions workflow

Add the spec, build/test/sign/publish scripts, and workflow to this repository.
This makes the delivery contract reviewable with the source, but requires an
approved self-hosted GitHub runner with Docker/network access and protected
repository or environment secrets for Nexus/Spacewalk/signing.

### Option B: repository-owned scripts called by the existing Jenkins job

Add the same spec and scripts here but retain Jenkins as the execution backend.
This minimizes runner migration, but the exact job repository, credential IDs,
branch/tag event contract, artifact retention, and pull-request status reporting
must first be supplied and brought under review.

The packaging implementation is blocked until one option is selected. Adding a
GitHub workflow that cannot reach the internal services, or changing an unknown
Jenkins job outside source control, would not create a reliable delivery path.

## 8. Required Test Gates

Before the first build:

1. preserve all 116 legacy payload paths and the three explicit exclusions;
2. preserve exact file and directory modes;
3. preserve the observed Requires and Provides set;
4. preserve scriptlet behavior or approve separately tested changes;
5. prove that JEM-HN and JEM Core do not co-own shared directories;
6. run the JEM Core action-dispatch Bats suite and shell syntax checks;
7. prohibit publication from default branches and pull requests;
8. reject unsigned, SHA1-signed, wrong-key, and invalid-signature artifacts.

After a candidate is built:

1. compare RPM headers, file list, modes, Requires, Provides, and scriptlets
   against the runtime inventory in this RFC;
2. install both EL7 and EL10 candidates with normal GPG enforcement;
3. verify that the repository public key, not a local bypass, establishes trust;
4. install JEM-HN in the same transaction and confirm no ownership conflict;
5. rerun the packaged JEM Core and JEM-HN smoke matrices on disposable nodes.

## 9. Rollback

No existing RPM or external Jenkins job is removed until the native package
passes parity and runtime gates. Existing published NEVRAs remain immutable.
Failed snapshots are removed through the normal Spacewalk administration path,
followed by regeneration of only the affected channel. A stable correction
uses a higher manually assigned release number.
