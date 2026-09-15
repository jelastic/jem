# RFC-0001: Core Action Dispatch Contract

## Status

Implemented and runtime-verified for the JEM 9.0.1 development branch.

## Context

JEM Core previously ignored a nonzero `pre<Action>Callback` result and always
executed the action body. A validation callback could therefore emit an error
response while the backend operation still ran and emitted a second response.

Action discovery also treated every function whose name began with the two
characters `do` as public. Helpers beginning with `docker` were consequently
shown as actions with the first two characters removed. Dispatch compounded
this by selecting the first function declaration containing the requested
substring.

## Decision

`executeActionLifecycle` is the single owner of pre-callback, action, and
post-callback ordering. A nonzero pre-callback status is returned unchanged and
prevents both later phases. A nonzero action status prevents the post-callback.

`listPublicActions` and `resolvePublicAction` define one shared registry.
Public functions use `do` followed by an uppercase action name. Four existing
lowercase exceptions (`fwset`, `getPCSTemplate`, `isEnabled`, `setupUtils`, and
`usage`) are explicit compatibility entries. Internal `doAction` and all
`docker*` helpers are excluded. Dispatch is an exact case-insensitive match and
rejects partial or substring matches.

Help and Usage enumerate the same registry used by dispatch.

## Compatibility

Existing public action spelling remains case-insensitive. The five observed
legacy lowercase action functions remain callable. Undocumented dispatch into
arbitrary helper functions is intentionally removed.

## Verification

Bats contracts cover:

- failed pre-callback status propagation and backend suppression;
- full `doAction` propagation with one response and no backend marker;
- successful pre/action/post ordering;
- action failure suppressing the post-callback;
- exclusion of `docker*` helpers and internal `doAction`;
- exact case-insensitive resolution and rejection of substring lookup;
- explicit legacy lowercase compatibility entries.

Local verification passes all `7/7` Bats contracts, Bash syntax validation,
and `git diff --check`. A combined static scan classified 185 action-like
functions across JEM and JEM-HN: five explicit lowercase compatibility actions,
16 private `docker*` helpers, and no unclassified lowercase candidate.

The JEM Core candidate was overlaid on VZ10 canary `10.136.20.141` without an
RPM build. `jem agent Create --ctid 990104` without an OS template returned
exactly one JSON document, exit `99`, and result `4099`; CT `990104` did not
exist before or after the call. This confirms that the failed pre-callback did
not invoke `vzctl create`.

`jem docker Help` returned success, retained the expected public actions and
the explicit legacy `getPCSTemplate`, and exposed zero action lines beginning
with `cker`. A direct call to `ckerContainerRootForId` was rejected as an
unknown action. CT and Docker container inventories remained empty. Temporary
uploads were removed; the tested source overlay and rollback copies remain on
the canary.
