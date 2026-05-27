# ``SwiftSTAC``

Read, write, and manipulate SpatioTemporal Asset Catalogs (STAC) from native Swift.

## Overview

SwiftSTAC is a port of [PySTAC](https://github.com/stac-utils/pystac). The
mental model is the same: a STAC document is one of three things — a
``Catalog``, a ``Collection``, or an ``Item`` — connected by ``Link``s and
sometimes carrying ``Asset``s. SwiftSTAC gives you typed access to the
fields, lossless round-trip through JSON, link resolution against the
filesystem or HTTP, and accessors for 22 STAC extensions.

The entry point for reading is ``Catalog/fromFile(_:stacIO:)`` (dispatches
to whichever concrete type the document declares). For writing, build the
tree in memory and call ``Catalog/normalizeAndSave(rootHref:catalogType:strategy:stacIO:)``.

```swift
import SwiftSTAC

// Read
let obj = try Catalog.fromFile("/path/to/catalog.json")
if let catalog = obj as? Catalog {
    for (cat, _, items) in try catalog.walkResolving() {
        print(cat.id, "→", items.map(\.id))
    }
}

// Build + save
let root = Catalog(id: "root", description: "demo", catalogType: .selfContained)
let coll = Collection(
    id: "imagery", description: "Imagery",
    extent: Extent(
        spatial: SpatialExtent(bboxes: [[-180, -90, 180, 90]]),
        temporal: TemporalExtent(intervals: [[nil, nil]])
    )
)
let item = try Item(
    id: "scene-1",
    geometry: nil, bbox: [0, 0, 1, 1],
    datetime: Date(), properties: [:]
)
try root.addChild(coll)
try coll.addItem(item)
try root.normalizeAndSave(rootHref: "/tmp/my-catalog")
```

## Topics

### Building a STAC tree

- ``Catalog``
- ``Collection``
- ``Item``
- ``Asset``
- ``Link``
- ``Provider``

### Reading and writing

- ``StacIO``
- ``DefaultStacIO``
- ``Catalog/fromFile(_:stacIO:)``
- ``Item/fromFile(_:stacIO:)``
- ``Collection/fromCollectionFile(_:stacIO:)``
- ``STACObject/saveObject(includeSelfLink:destHref:stacIO:)``
- ``Link/resolveSTACObject(root:stacIO:)``
- ``Catalog/walkResolving(stacIO:)``

### Laying out a catalog on disk

- ``HrefLayoutStrategy``
- ``BestPracticesLayoutStrategy``
- ``AsIsLayoutStrategy``
- ``Catalog/normalizeHrefs(rootHref:strategy:stacIO:resolveAll:)``
- ``Catalog/save(catalogType:stacIO:includeSelfLink:)``
- ``Catalog/normalizeAndSave(rootHref:catalogType:strategy:stacIO:)``
- ``CatalogType``

### Walking and transforming trees

- ``Catalog/walk()``
- ``Catalog/getChildren()``
- ``Catalog/getItems(ids:recursive:)``
- ``Catalog/getAllItems()``
- ``Catalog/getAllCollections()``
- ``Catalog/clone()``
- ``Catalog/mapItems(_:)-((Item)->Item)``
- ``Catalog/mapItems(_:)-((Item)->[Item])``
- ``Catalog/mapAssets(_:)``
- ``Catalog/describe(includeHrefs:indent:output:)``
- ``Catalog/fullyResolve(stacIO:)``

### Collection-specific metadata

- ``Extent``
- ``SpatialExtent``
- ``TemporalExtent``
- ``Summaries``
- ``RangeSummary``
- ``ItemAssetDefinition``
- ``ProviderRole``
- ``Collection/updateExtentFromItems()``

### Item-specific behavior

- ``Item/setCollection(_:)``
- ``Item/getCollection()``
- ``Item/addDerivedFrom(_:)``
- ``Item/getDerivedFrom()``
- ``Item/setDatetime(_:asset:)``
- ``Item/getDatetime(asset:)``
- ``ItemCollection``

### Common metadata

- ``CommonMetadata``
- ``CommonMetadataHost``

### Link graph

- ``RelType``
- ``MediaType``
- ``STACObjectType``
- ``STACObject/getRoot()``
- ``STACObject/setRoot(_:)``
- ``STACObject/getParent()``
- ``STACObject/setParent(_:)``
- ``STACObject/getSelfHref()``
- ``STACObject/setSelfHref(_:)``
- ``STACObject/targetInHierarchy(_:)``

### STAC Extensions

- ``EOExtension``
- ``ProjectionExtension``
- ``RasterExtension``
- ``LabelExtension``
- ``ViewExtension``
- ``SARExtension``
- ``SatExtension``
- ``ScientificExtension``
- ``FileExtension``
- ``VersionExtension``
- ``MLMExtension``
- ``DatacubeExtension``
- ``ClassificationExtension``
- ``GridExtension``
- ``MGRSExtension``
- ``PointCloudExtension``
- ``RenderExtension``
- ``StorageExtension``
- ``TableExtension``
- ``TimestampsExtension``
- ``XarrayAssetsExtension``
- ``STACExtension``
- ``ExtensionHost``
- ``PropertiesExtensionAccessor``

### JSON building blocks

- ``JSONValue``

### HREF and date utilities

- ``HREFUtils``

### Version

- ``STACVersion``

### Errors

- ``STACError``
