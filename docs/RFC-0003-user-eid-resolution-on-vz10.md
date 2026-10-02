# RFC 0003: User EID Resolution on VZ10

- Status: Implemented
- Scope: `user.module` Add preflight
- Compatibility target: PVA-managed VZ7 and PVA-less VZ10 containers

## Context

The Jelastic AddNode flow invokes `jem user add --eid` after the agent and
Docker setup stages. Legacy `user.module` resolved that EID exclusively through
`/var/opt/pva/agent/etc/configs/<eid>`, where PVA publishes a mapping to CTID.

On VZ10 without PVA, `agent.module` owns the EID and stores it in
`<private>/.vza/eid.conf`. The agent Create and GetInfo responses therefore
contained the correct EID, but the later user Add action returned result `4105`
(`Container not found`) because no PVA configuration file existed.

## Decision

Introduce a narrow EID resolver for `user.module`:

1. Validate the EID as a non-empty opaque identifier of at most 255 characters
   containing only ASCII letters, digits, dot, underscore, colon, or hyphen.
2. Preserve an existing PVA configuration as the authoritative mapping on
   legacy hosts.
3. When no PVA mapping exists, query the container inventory once for CTID and
   private path pairs and compare the exact content of each readable
   `<private>/.vza/eid.conf` file.
4. Accept exactly one metadata match. Missing, malformed, or duplicated
   metadata retains the established result `4105` response.
5. Treat inventory, paths, and metadata as data. Do not evaluate their content
   or construct a shell command from the EID.
6. Replace the unavailable `vzreadlink` call in the same Add path with the
   packaged `vzctPath` adapter, which delegates root-aware resolution to
   `resolvepath` and preserves path arguments without command construction.

No public CLI parameters or successful response formats change.

## Compatibility

PVA-managed VZ7 behavior is unchanged because the legacy mapping is checked
first. The fallback aligns `user.module` with the EID ownership already used by
the VZ10 `agent.module`. Private paths containing spaces are supported.

## Test strategy

Bats contracts cover legacy PVA priority, VZ10 metadata lookup, a private path
containing spaces, rejection of an unsafe EID, malformed metadata, and
duplicate metadata. Path contracts cover typed root and container paths plus
empty-path rejection. A callback contract also verifies that successfully
resolved application ownership produces a zero callback status. Runtime
acceptance requires a disposable VZ10 container whose EID exists only in
`.vza/eid.conf`, followed by the production sequence of Docker setup, guest JEM
installation, `jem user add --eid`, and cleanup.

## Runtime acceptance

Runtime verification on 2026-10-02 used disposable VZ10 AlmaLinux 9
Apache/PHP CT 11996. The agent stored its test EID only in
`<private>/.vza/eid.conf`; the corresponding PVA configuration was absent.
The test reproduced the production order: Docker setup completed, then
`jem install package --name jem --version 9.0.1` installed the guest runtime,
and finally the hardnode invoked `jem user add --eid`.

The first complete attempt exposed a lifecycle defect after successful EID and
application-owner resolution: the final guard in `preAddCallback` evaluated to
false when both UID and GID were present, so the callback returned status 1.
The core aborted the action and the hardnode wrapper returned result `4045`
with an empty message. The callback now returns zero explicitly after its
guards have passed.

With both changes installed, the command returned result 0, reported homedir
`/var/www` and data owner `700:700`, created the `jelastic` guest account, and
generated its SSH key. This acceptance exercised the VZ10 metadata fallback
without a PVA mapping. The disposable container was destroyed after evidence
collection.
