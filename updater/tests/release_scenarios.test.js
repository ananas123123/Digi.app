"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const { evaluateRelease } = require("../version_comparison");

const fixturePath = join(__dirname, "fixtures", "release_scenarios.json");
const fixture = JSON.parse(readFileSync(fixturePath, "utf8"));

for (const scenario of fixture.scenarios) {
  test("controlled release scenario: " + scenario.name, () => {
    const result = evaluateRelease(scenario.installed_version, scenario.manifest);
    assert.equal(result.status, scenario.expected_status);
  });
}

test("fixture contains all required controlled scenarios", () => {
  const names = new Set(fixture.scenarios.map(scenario => scenario.name));
  for (const required of [
    "newer published release",
    "same published release",
    "older published release",
    "newer but unpublished release",
    "wrong product metadata",
    "unsupported schema metadata",
    "malformed latest version"
  ]) {
    assert.ok(names.has(required), "Missing scenario: " + required);
  }
});
