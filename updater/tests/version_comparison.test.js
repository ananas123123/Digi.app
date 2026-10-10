"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { compareVersions, evaluateRelease } = require("../version_comparison");

test("detects a newer remote version", () => {
  assert.equal(compareVersions("1.1.0.0", "1.0.0.0"), 1);
});
test("detects an older remote version", () => {
  assert.equal(compareVersions("1.0.0.0", "1.1.0.0"), -1);
});
test("recognises equal versions", () => {
  assert.equal(compareVersions("1.0.0.0", "1.0.0.0"), 0);
});
test("compares numeric components rather than strings", () => {
  assert.equal(compareVersions("1.0.10.0", "1.0.9.0"), 1);
});
test("treats missing trailing components as zero", () => {
  assert.equal(compareVersions("1.2", "1.2.0.0"), 0);
});
test("rejects malformed versions", () => {
  for (const value of ["", "1.x.0.0", "1..0", "-1.0", "1.2.3.4."]) {
    assert.equal(compareVersions(value, "1.0.0.0"), null, value);
  }
});
test("rejects non-string values and unsafe numeric components", () => {
  assert.equal(compareVersions(null, "1.0"), null);
  assert.equal(compareVersions("1.0", 1), null);
  assert.equal(compareVersions("999999999999999999999.0", "1.0"), null);
});
function manifest(overrides = {}) {
  return { product: "Digi", schema_version: 1, release_status: "published", latest_version: "1.1.0.0", ...overrides };
}
test("offers a newer published version", () => {
  const result = evaluateRelease("1.0.0.0", manifest());
  assert.equal(result.status, "update");
  assert.equal(result.packagePublished, true);
});
test("announces a newer version even when its package is unpublished", () => {
  const result = evaluateRelease("1.0.1.0", manifest({ latest_version: "1.2.0.0", release_status: "unpublished" }));
  assert.equal(result.status, "update");
  assert.equal(result.latestVersion, "1.2.0.0");
  assert.equal(result.packagePublished, false);
});
test("does not offer an equal or older version", () => {
  assert.equal(evaluateRelease("1.1.0.0", manifest({ latest_version: "1.1.0.0" })).status, "current");
  assert.equal(evaluateRelease("1.2.0.0", manifest({ latest_version: "1.1.0.0" })).status, "current");
});
test("unpublished metadata with no version remains current", () => {
  assert.equal(evaluateRelease("1.0.0.0", manifest({ release_status: "unpublished", latest_version: "" })).status, "current");
});
test("rejects invalid release metadata and version strings", () => {
  assert.equal(evaluateRelease("1.0.0.0", manifest({ product: "Other" })).status, "invalid");
  assert.equal(evaluateRelease("1.0.0.0", manifest({ latest_version: "1.x" })).status, "invalid");
});
