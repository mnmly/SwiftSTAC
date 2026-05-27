# SwiftSTAC

A Swift port of [PySTAC](https://github.com/stac-utils/pystac) — read, write,
and manipulate [SpatioTemporal Asset Catalogs](https://stacspec.org/) from
native Swift on Apple platforms and Linux.

```swift
import SwiftSTAC

let catalog = try Catalog.fromFile("/path/to/catalog.json")
for case let (cat, _, items) in try (catalog as! Catalog).walkResolving() {
    print(cat.id, "→", items.map(\.id))
}
```

## What's included

- **Core domain**: `Catalog`, `Collection`, `Item`, `Asset`, `Link`,
  `Provider`, `ItemCollection`, `ItemAssetDefinition`, `Extent` (Spatial /
  Temporal), `Summaries`, `CommonMetadata`.
- **JSON I/O**: round-trips through pystac JSON. `Catalog.fromFile(_:)`,
  `STACObject.saveObject()`, `Link.resolveSTACObject(...)`,
  `Catalog.walkResolving()`.
- **Layout & save**: `BestPracticesLayoutStrategy`, `normalizeHrefs(...)`,
  `save(...)`, `normalizeAndSave(...)`.
- **Transforms**: `mapItems`, `mapAssets`, `clone()`,
  `Collection.updateExtentFromItems()`, `Item.add/get/removeDerivedFrom`.
- **22 STAC extensions** with typed accessors:
  - `eo`, `projection`, `raster`, `label`, `view`, `sar`, `sat`, `scientific`,
    `version`, `file`, `mlm`, `datacube`, `classification`, `grid`, `mgrs`,
    `pointcloud`, `render`, `storage`, `table`, `timestamps`,
    `xarray-assets`, `item_assets`.

## Quick examples

```swift
// Build a tree and save it
let root = Catalog(id: "root", description: "demo", catalogType: .selfContained)
let coll = Collection(
    id: "imagery",
    description: "Imagery",
    extent: Extent(
        spatial: SpatialExtent(bboxes: [[-180, -90, 180, 90]]),
        temporal: TemporalExtent(intervals: [[nil, nil]])
    )
)
let item = try Item(
    id: "scene-1",
    geometry: nil, bbox: [0, 0, 1, 1],
    datetime: Date(),
    properties: [:]
)
try root.addChild(coll)
try coll.addItem(item)
try root.normalizeAndSave(rootHref: "/tmp/my-catalog")
```

```swift
// Read fields through extensions
let item = try Item.fromFile("/path/to/item.json")
print(item.eo.cloudCover, item.proj.epsg, item.sar.polarizations as Any)

// Write fields — the extension registers its schema URI automatically
item.eo.cloudCover = 12.3
item.proj.epsg = 32633
print(item.stacExtensions)
// → ["https://stac-extensions.github.io/eo/v1.1.0/schema.json",
//    "https://stac-extensions.github.io/projection/v2.0.0/schema.json"]
```

## Status

170 unit tests covering the unit-level surface of the corresponding pystac
test files. Designed for functional parity with pystac for the in-memory
domain model and local-file IO.

**Deliberately out of scope** (consider these follow-ups, not bugs):

- STAC API HTTP client (separate `pystac-client` package upstream).
- JSON Schema validation (`validate()`, `validate_all()`).
- Pre-1.0 STAC document migration (`migrate_to_latest`).
- Object-identity cache (`ResolvedObjectCache`) across links pointing to the
  same href from different owners.
- `Asset.move/copy/delete` filesystem mutation.
- Windows paths (POSIX only on Apple platforms and Linux).
- Bundled `fields-normalized.json` for `Summarizer`.

## Requirements

- Swift 5.10+
- macOS 13+, iOS 16+, tvOS 16+, watchOS 9+, or Linux

## Install

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/<owner>/SwiftSTAC.git", from: "0.1.0"),
```

## Acknowledgements

This is a port of [stac-utils/pystac](https://github.com/stac-utils/pystac) by
the PySTAC authors. See `NOTICE` for attribution.

## License

[Apache License 2.0](./LICENSE).
