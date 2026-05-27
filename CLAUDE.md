# SwiftSTAC — agent notes

This package is a Swift port of [PySTAC](https://github.com/stac-utils/pystac).
The goal is functional parity with pystac's in-memory domain model and
local-file I/O.

## Working invariants

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

- STAC API HTTP client (a separate package upstream).
- JSON Schema validation.
- Pre-1.0 STAC document migration.
- `ResolvedObjectCache` for cross-link object identity.
- Windows path handling.

See `README.md` for the full list with reasoning.
