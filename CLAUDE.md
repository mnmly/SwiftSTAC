# SwiftSTAC — agent notes

This package is a Swift port of [PySTAC](https://github.com/stac-utils/pystac).
The goal is functional parity with pystac's in-memory domain model and
local-file I/O.

## Working invariants

- **All I/O is `async throws`.** `StacIO.readText`, `StacIO.writeText`,
  `Catalog.fromFile`, `STACObject.saveObject`, `Link.resolveSTACObject`,
  `Catalog.walkResolving`, `Catalog.fullyResolve`, `Catalog.normalizeHrefs`,
  `Catalog.save`, `Catalog.normalizeAndSave`. Never reintroduce a blocking
  semaphore or sync HTTP path.
- **STAC reference types are not `Sendable`.** `Item`, `Catalog`,
  `Collection`, `Asset`, `Link`, `ItemCollection` are mutable classes —
  callers must confine each instance to a single isolation domain. The
  domain model is intentionally not `@unchecked Sendable`; if shared-state
  use is needed, wrap in an actor.
- **Process-wide mutable state lives behind locks or actors.** See
  `StacIORegistry` (actor) and `STACVersion.OverrideStorage` (lock).
- **The package compiles clean under `-strict-concurrency=complete`.**
  Canonical build invocation:
  `swift build -Xswiftc -strict-concurrency=complete`. CI fails on warnings.
- **Don't break pystac wire compatibility.** JSON round-trip via
  `toDict` / `fromDict` (or `Collection.parse(_:)`) must produce dicts
  that pystac will load without error and vice-versa. Most fields are
  preserved verbatim through `JSONValue` / `extraFields` even when there's
  no typed accessor.
- **Catalog cannot strongly retain itself through its root link.** A
  Catalog with `rootIsSelf == true` has no `Link(rel: "root", target: self)`
  in its `links` array; `getRoot()` returns `self` directly and the root
  link is synthesized at `toDict()` time. Adding a self → self link would
  create a leak.
- **Mutating extension setters auto-register the schema URI** on the
  owning Item (or on the Asset's owner for asset-hosted extensions).
  Don't bypass `registerSchema(_:)` when adding new accessors.
- **Tests use vendored pystac fixtures** under
  `Tests/SwiftSTACTests/Fixtures/`. If you need a new fixture, copy it
  from `../python/pystac/tests/data-files/` and add to that tree.

## Cross-platform constraints

- `URLSession` lives in `FoundationNetworking` on Linux. Anywhere a new
  source file uses `URLSession`, guard the import:
  ```swift
  #if canImport(FoundationNetworking)
  import FoundationNetworking
  #endif
  ```
- `CoreFoundation` (`CFGetTypeID`, `CFBooleanGetTypeID`, etc.) is
  Darwin-only. Don't reach for it. To distinguish a Bool-wrapped
  `NSNumber` cross-platform, use `String(cString: n.objCType) == "c"`.
- `NSLock.withLock` is Apple Foundation only. On Linux Swift 5.10 use
  `lock(); defer { lock.unlock() }`.
- Linux requires Swift 6.0+ because `URLSession.data(for:)` only landed
  in `FoundationNetworking` with that release.

## Upstream sync workflow

The current upstream snapshot is pinned in two places that must stay in
lockstep:

- `Sources/SwiftSTAC/STACVersion.swift` →
  `STACVersion.portedFromPystac` + `STACVersion.portedFromPystacCommit`
- `README.md` → "Compatibility with PySTAC" table

When syncing from a newer PySTAC release, do these steps in order:

1. Read the upstream `CHANGELOG.md` between the currently-pinned commit
   and the new target. Identify changes that touch SwiftSTAC's surface
   (domain model, IO, extensions). Wire-format-only fields land in
   `JSONValue` / `extraFields` automatically — skip those.
2. Port the changes. Each new public symbol needs a `///` comment and,
   if it belongs in the curated sidebar, an entry under the right
   `## Topics` group in `Sources/SwiftSTAC/Documentation.docc/SwiftSTAC.md`.
3. Port the corresponding pystac tests (under `../python/pystac/tests/`)
   or extension tests (`../python/pystac/extensions/<ext>/tests/`).
   Vendor any new fixtures into `Tests/SwiftSTACTests/Fixtures/`.
4. Update `STACVersion.portedFromPystac` and
   `STACVersion.portedFromPystacCommit` to the new upstream tag and
   commit short hash.
5. Add a `CHANGELOG.md` entry. Lead with
   `Tracks **pystac X.Y.Z** (commit \`...\`).`
6. Add a row to the README compatibility table.
7. Verify:
   ```bash
   swift test -Xswiftc -strict-concurrency=complete
   Scripts/build_docs.sh           # zero new warnings
   ```
8. Pick the SwiftSTAC SemVer bump based on **SwiftSTAC's** API delta, not
   pystac's:
   - Breaking change to SwiftSTAC's public API → minor bump while <1.0,
     major bump once we hit 1.0.
   - Additive only → patch or minor.
   - Internal refactor + fixture refresh → patch.
9. Cut the release (see "Releasing" below).

## Releasing

Tags are unprefixed (`0.2.1`, not `v0.2.1`). Each tagged commit gets a
GitHub Release with notes derived from the CHANGELOG entry.

```bash
git tag -a 0.X.Y -m "0.X.Y — <one-line summary>"
git push --follow-tags

gh release create 0.X.Y --title "0.X.Y — <one-line summary>" --notes "$(...)"
gh release edit 0.X.Y --latest        # if multiple releases were just made
```

CI must be green on `main` before the tag is pushed. The CI workflow at
`.github/workflows/ci.yml` runs the strict-concurrency build + test on
macOS 15 and Linux Swift 6.0; any new failure mode there should be
fixed in `main` before tagging.

## Documentation

SwiftSTAC ships DocC-generated reference docs (see
`Sources/SwiftSTAC/Documentation.docc/` and `Scripts/build_docs.sh`).
**`///` doc comments on public/`open` symbols are published** to the
static site at https://mnmly.github.io/SwiftSTAC/ and (if
`EMIT_LLMS_TXT=1` is used) into `docs/llms.txt`.

When you add or modify a `public` or `open` declaration:

- Write a `///` doc comment. One-sentence summary, then a paragraph if
  the *why* is non-obvious. Skip restating what the signature already
  says.
- Document each parameter with `- Parameter name:` (use the **internal**
  name when there's an external label — DocC warns otherwise).
- Cross-reference related symbols with double-backtick links, e.g.
  `` ``OtherType/method(_:)`` ``. DocC link syntax is signature-
  sensitive: `foo(_:)` and `foo(_:_:)` are different.
- For `open func` override points with empty bodies, the doc comment
  must explain *what to override it for*, *what the arguments mean*,
  and *what the default behavior is*. These methods are the API surface
  — the comment is the only spec a subclasser sees.
- When you add a new top-level symbol that belongs in the curated
  sidebar, add it under the appropriate `## Topics` group in
  `Sources/SwiftSTAC/Documentation.docc/SwiftSTAC.md`. Topics are
  organized by *user task*, not alphabetic order.

Verify before declaring documentation work done:

```bash
Scripts/build_docs.sh
```

Expect exit 0 and no new "doesn't exist at" or "external name used to
document parameter" warnings attributable to your changes.

## Out-of-scope (don't try to fill these without asking)

- STAC API HTTP client (a separate package — see the **SwiftSTACClient**
  port that should live alongside this repo).
- JSON Schema validation.
- Pre-1.0 STAC document migration.
- `ResolvedObjectCache` for cross-link object identity.
- Windows path handling.

See `README.md` for the full list with reasoning.
