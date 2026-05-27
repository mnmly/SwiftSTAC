import Foundation

/// A list of common media types that can be used in STAC Asset and Link metadata.
///
/// Mirrors `pystac.media_type.MediaType`. Backed by `String` so unknown media types
/// can flow through unchanged by using the underlying string at the call site.
public enum MediaType: String, Sendable, Codable, CaseIterable {
    case cog = "image/tiff; application=geotiff; profile=cloud-optimized"
    case flatgeobuf = "application/vnd.flatgeobuf"
    case geojson = "application/geo+json"
    case geopackage = "application/geopackage+sqlite3"
    case geotiff = "image/tiff; application=geotiff"
    case hdf = "application/x-hdf"
    case hdf5 = "application/x-hdf5"
    case html = "text/html"
    case jpeg = "image/jpeg"
    case jpeg2000 = "image/jp2"
    case json = "application/json"
    case png = "image/png"
    case text = "text/plain"
    case tiff = "image/tiff"
    case kml = "application/vnd.google-earth.kml+xml"
    case xml = "application/xml"
    case pdf = "application/pdf"
    case netcdf = "application/netcdf"
    case copc = "application/vnd.laszip+copc"
    case vndPmtiles = "application/vnd.pmtiles"
    case vndApacheParquet = "application/vnd.apache.parquet"
    case vndZarr = "application/vnd.zarr"

    // Deprecated
    case parquet = "application/x-parquet"
    case zarr = "application/vnd+zarr"
}

extension MediaType {
    /// Media types that can be resolved as STAC objects.
    public static let stacJSON: [MediaType?] = [nil, .geojson, .json]
}
