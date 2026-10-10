# Release manifest contract

This document defines the metadata Digi must receive before it can download an update.

## Existing fields

Keep these existing top-level fields:
- `schema_version`: supported manifest format; currently `1`.
- `product`: must be `"Digi"`.
- `channel`: release channel, such as `"stable"`.
- `latest_version`: version announced to users.
- `release_status`: `"published"` or `"unpublished"`.
- `message`: optional human-readable status.
- `release`: details for the announced version.

## Package fields for a downloadable release

A published release that can be downloaded must include a `release.package` object with all three fields:

- `url`: direct HTTPS URL to the actual update package (not a releases page).
- `size_bytes`: exact package size in bytes, as a positive integer.
- `sha256`: SHA-256 checksum of the exact package file, as 64 hexadecimal characters.

The package version must match `latest_version` and `release.version`.

Digi must not download a package when any required field is missing or invalid. It must not treat a web page URL as a package URL. A checksum must be calculated from the final package file after packaging; never invent or manually estimate it.

## Unpublished and temporary metadata

An unpublished announcement may omit `release.package`. It must not be downloadable.

The current live `latest.json` is labelled as a temporary test simulation and says no package is available. Do not add fake package fields or treat its current `release_status` value as proof that a real package exists. Correct the live release metadata only when the actual package has been built, uploaded, measured, and hashed.

## Example shape (illustrative only)

This example uses placeholder values and is not a real release. Do not publish it as-is.

```json
{
  "schema_version": 1,
  "product": "Digi",
  "channel": "stable",
  "latest_version": "1.2.0.0",
  "release_status": "published",
  "release": {
    "version": "1.2.0.0",
    "package": {
      "url": "https://downloads.example.invalid/Digi-1.2.0.0.exe",
      "size_bytes": 123456,
      "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  }
}
```

The URL, size, and checksum above are placeholders, not usable package details.

## Security boundary

SHA-256 and size checks detect corruption or a package that differs from the published metadata. They do not, by themselves, prove who published the metadata. Digi must obtain the manifest over HTTPS from the configured trusted repository. Publisher authenticity via digital signature is a separate possible enhancement.
