# Changelog

All notable changes to **SwiftSTAC** are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and SwiftSTAC
adheres to [Semantic Versioning](https://semver.org/) (tags are
unprefixed: `0.2.1`, not `v0.2.1`).

Each release pins the upstream **PySTAC** version it tracks, exposed at
runtime via `STACVersion.portedFromPystac` and
`STACVersion.portedFromPystacCommit`.

## [0.2.1] — 2026-05-27

Tracks **pystac 1.15.0-rc.0** (commit `6184a7ca`).

### Added

- `STACVersion.portedFromPystac` and `STACVersion.portedFromPystacCommit`
  constants so consumers can discover upstream compatibility at runtime.
- `CHANGELOG.md` (this file).
- README "Compatibility" section.

### Fixed

- Linux build: `URLSession` now imported from `FoundationNetworking` when
  available; `CFGetTypeID` / `CFBooleanGetTypeID` replaced with an
  `objCType`-based NSNumber-bool check; `NSLock.withLock` replaced with
  the `lock()/unlock()+defer` pattern (Swift 5.10 Linux compatibility).
- CI matrix narrowed to Swift 6.0+ on Linux. Apple platforms still build
  on Swift 5.10+.

## [0.2.0] — 2026-05-27

Tracks **pystac 1.15.0-rc.0** (commit `6184a7ca`).

### Changed (breaking)

- `StacIO` is `async`-only. `readText`, `writeText`, `readJSON`,
  `saveJSON`, `readSTACObject` are now `async throws`. `DefaultStacIO`
  uses `URLSession.data(for:)`; the previous `DispatchSemaphore` blocking
  path is gone.
- `Catalog.fromFile`, `Item.fromFile`, `Collection.fromCollectionFile`,
  `STACObject.saveObject`, `Link.resolveSTACObject`,
  `Catalog.walkResolving`, `Catalog.fullyResolve`,
  `Catalog.normalizeHrefs`, `Catalog.save`, `Catalog.normalizeAndSave`
  are all `async throws`.
- Domain reference types (`Item`, `Catalog`, `Collection`, `Asset`,
  `Link`, `ItemCollection`) no longer claim `@unchecked Sendable`.
  Callers must confine each instance to a single isolation domain.
- `StacIORegistry` is now an `actor`. `STACVersion`'s override slot is
  guarded by an explicit `NSLock`.

### Added

- Package compiles clean under `swift build -Xswiftc -strict-concurrency=complete`
  with zero warnings.

## [0.1.0] — 2026-05-27

Tracks **pystac 1.15.0-rc.0** (commit `6184a7ca`).

### Added

- Initial port of PySTAC to Swift.
- Domain model: `Catalog`, `Collection`, `Item`, `Asset`, `Link`,
  `Provider`, `Extent` (`SpatialExtent` / `TemporalExtent`),
  `Summaries`, `ItemCollection`, `ItemAssetDefinition`, `CommonMetadata`.
- Sync `StacIO` with file + HTTP read/write (replaced in 0.2.0).
- Layout: `BestPracticesLayoutStrategy`, `AsIsLayoutStrategy`,
  `normalizeHrefs`, `save`, `normalizeAndSave`.
- Catalog walking + link resolution.
- 22 STAC extensions: eo, projection, raster, label, view, sar, sat,
  scientific, version, file, mlm, datacube, classification, grid, mgrs,
  pointcloud, render, storage, table, timestamps, xarray-assets,
  item_assets.
- 170 unit tests covering the unit-level surface of the corresponding
  pystac suites, backed by vendored pystac fixtures.
- DocC documentation site (`Scripts/build_docs.sh`).
