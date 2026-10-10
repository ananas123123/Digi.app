"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const DigiVersionComparison = require("../version_comparison");
const checkerSource = fs.readFileSync(path.join(__dirname, "..", "update_checker.js"), "utf8");

async function runChecker({ installedVersion = "1.0.0.0", response } = {}) {
  const listeners = new Map();
  const storage = new Map();
  const dot = { dataset: {}, title: "", attributes: {}, setAttribute(name, value) { this.attributes[name] = value; } };
  const document = {
    readyState: "complete",
    getElementById(id) { return id === "digi-update-status" ? dot : null; },
    addEventListener() {},
    createElement() { return { style: {}, setAttribute() {}, textContent: "", id: "" }; },
    body: { appendChild() {} }
  };
  const window = {
    DigiVersionComparison, setTimeout, clearTimeout, setInterval() { return 1; },
    addEventListener(name, callback) { if (!listeners.has(name)) listeners.set(name, new Set()); listeners.get(name).add(callback); },
    removeEventListener(name, callback) { if (listeners.has(name)) listeners.get(name).delete(callback); },
    dispatchEvent(event) { for (const callback of listeners.get(event.type) || []) callback(event); },
    digiBackend: {
      state(callback) { callback(JSON.stringify({ version: installedVersion })); },
      checkReleaseManifest() { window.dispatchEvent({ type: "digi-release-manifest", detail: JSON.stringify(response) }); }
    }
  };
  const localStorage = {
    getItem(key) { return storage.has(key) ? storage.get(key) : null; },
    setItem(key, value) { storage.set(key, String(value)); },
    removeItem(key) { storage.delete(key); }
  };
  vm.runInNewContext(checkerSource, { window, document, localStorage, Date, Promise, JSON, String, Error }, { filename: "update_checker.js" });
  await new Promise(resolve => setImmediate(resolve));
  return { dot, storage };
}
function manifest(overrides = {}) {
  return { product: "Digi", schema_version: 1, release_status: "published", latest_version: "1.1.0.0", ...overrides };
}

test("newer published release sets red/update status and pending version", async () => {
  const { dot, storage } = await runChecker({ response: { ok: true, manifest: manifest() } });
  assert.equal(dot.dataset.status, "update");
  assert.equal(storage.get("digi.updateChecker.pendingVersion"), "1.1.0.0");
});
test("newer unpublished announcement also sets update status without claiming package availability", async () => {
  const { dot, storage } = await runChecker({
    installedVersion: "1.0.1.0",
    response: { ok: true, manifest: manifest({ latest_version: "1.2.0.0", release_status: "unpublished" }) }
  });
  assert.equal(dot.dataset.status, "update");
  assert.match(dot.title, /announced/i);
  assert.match(dot.title, /not yet published/i);
  assert.equal(storage.get("digi.updateChecker.pendingVersion"), "1.2.0.0");
});
test("same version sets current status and clears pending version", async () => {
  const { dot, storage } = await runChecker({ response: { ok: true, manifest: manifest({ latest_version: "1.0.0.0" }) } });
  assert.equal(dot.dataset.status, "current");
  assert.equal(storage.has("digi.updateChecker.pendingVersion"), false);
});
test("older release does not offer a downgrade", async () => {
  const { dot, storage } = await runChecker({
    installedVersion: "1.1.0.0",
    response: { ok: true, manifest: manifest({ latest_version: "1.0.0.0" }) }
  });
  assert.equal(dot.dataset.status, "current");
  assert.equal(storage.has("digi.updateChecker.pendingVersion"), false);
});
test("unpublished feed without a version remains current", async () => {
  const { dot, storage } = await runChecker({
    response: { ok: true, manifest: manifest({ release_status: "unpublished", latest_version: "" }) }
  });
  assert.equal(dot.dataset.status, "current");
  assert.equal(storage.has("digi.updateChecker.pendingVersion"), false);
});
test("invalid metadata sets failure status", async () => {
  const { dot } = await runChecker({ response: { ok: true, manifest: manifest({ schema_version: 99 }) } });
  assert.equal(dot.dataset.status, "offline");
});
test("malformed latest version sets failure status", async () => {
  const { dot } = await runChecker({ response: { ok: true, manifest: manifest({ latest_version: "1.x.0.0" }) } });
  assert.equal(dot.dataset.status, "offline");
});
test("failed manifest request sets failure status", async () => {
  const { dot } = await runChecker({ response: { ok: false, manifest: null } });
  assert.equal(dot.dataset.status, "offline");
});
