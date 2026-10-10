"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { compareVersions } = require("../version_comparison");

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
