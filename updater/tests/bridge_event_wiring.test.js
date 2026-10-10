// Regression tests for the real Qt WebChannel-to-browser-event wiring.
//
// These tests inspect the production frontend source to ensure the bridge
// signal and updater listener use the same event contract. They do not claim
// to simulate a running Qt WebEngine instance.
//
// Run from the repository root:
//   node --test updater/tests/bridge_event_wiring.test.js

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "../..");
const appSource = fs.readFileSync(
  path.join(root, "frontend", "app.js"),
  "utf8"
);
const checkerSource = fs.readFileSync(
  path.join(root, "updater", "update_checker.js"),
  "utf8"
);
const htmlSource = fs.readFileSync(
  path.join(root, "frontend", "index.html"),
  "utf8"
);

test("Qt WebChannel release signal is forwarded as the updater browser event", () => {
  assert.match(
    appSource,
    /backend\.releaseManifestResult\.connect\(raw=>window\.dispatchEvent\(new CustomEvent\("digi-release-manifest",\{detail:raw\}\)\)\)/
  );
});

test("update checker listens for the same browser event", () => {
  assert.match(
    checkerSource,
    /window\.addEventListener\("digi-release-manifest",\s*onResult\)/
  );
  assert.match(
    checkerSource,
    /window\.removeEventListener\("digi-release-manifest",\s*onResult\)/
  );
});

test("version comparison module loads before the update checker", () => {
  const comparisonIndex = htmlSource.indexOf("../updater/version_comparison.js");
  const checkerIndex = htmlSource.indexOf("../updater/update_checker.js");

  assert.notEqual(comparisonIndex, -1, "version comparison script should be loaded");
  assert.notEqual(checkerIndex, -1, "update checker script should be loaded");
  assert.ok(
    comparisonIndex < checkerIndex,
    "version comparison module must load before update checker"
  );
});
