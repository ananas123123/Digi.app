"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { validatePackageMetadata } = require("../version_comparison");

function manifest(overrides = {}) {
  return {
    schema_version: 1,
    product: "Digi",
    channel: "stable",
    latest_version: "1.2.0.0",
    release_status: "published",
    release: {
      version: "1.2.0.0",
      package: {
        url: "https://downloads.example.com/Digi-1.2.0.0.exe",
        size_bytes: 123456,
        sha256: "a".repeat(64)
      }
    },
    ...overrides
  };
}

test("accepts complete, matching package metadata", () => {
  const result = validatePackageMetadata(manifest());
  assert.equal(result.valid, true);
  assert.equal(result.sizeBytes, 123456);
  assert.equal(result.sha256, "a".repeat(64));
});

test("rejects unpublished releases", () => {
  assert.equal(validatePackageMetadata(manifest({ release_status: "unpublished" })).reason, "release-unpublished");
});

test("rejects missing package details", () => {
  assert.equal(validatePackageMetadata(manifest({ release: { version: "1.2.0.0" } })).reason, "missing-package");
});

test("rejects HTTP, invalid and credential-bearing package URLs", () => {
  for (const url of [
    "http://downloads.example.com/file.exe",
    "not-a-url",
    "https://user:pass@downloads.example.com/file.exe",
    "https://downloads.example.com/file.exe#fragment"
  ]) {
    const value = manifest();
    value.release.package.url = url;
    assert.equal(validatePackageMetadata(value).valid, false, url);
  }
});

test("rejects invalid file sizes", () => {
  for (const size of [0, -1, 1.5, "123", Number.MAX_SAFE_INTEGER + 1, null]) {
    const value = manifest();
    value.release.package.size_bytes = size;
    assert.equal(validatePackageMetadata(value).reason, "invalid-package-size");
  }
});

test("rejects malformed SHA-256 values", () => {
  for (const checksum of ["", "a".repeat(63), "g".repeat(64), 123]) {
    const value = manifest();
    value.release.package.sha256 = checksum;
    assert.equal(validatePackageMetadata(value).reason, "invalid-package-sha256");
  }
});

test("rejects release version mismatches", () => {
  const value = manifest();
  value.release.version = "1.1.0.0";
  assert.equal(validatePackageMetadata(value).reason, "release-version-mismatch");
});

test("rejects invalid manifest identity and schema", () => {
  assert.equal(validatePackageMetadata(manifest({ product: "Other" })).reason, "invalid-manifest");
  assert.equal(validatePackageMetadata(manifest({ schema_version: 99 })).reason, "invalid-manifest");
});
