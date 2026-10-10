"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { DigiVersionComparison } = { DigiVersionComparison: require("../version_comparison") };

const checkerSource = fs.readFileSync(
  path.join(__dirname, "..", "update_checker.js"),
  "utf8"
);

async function runChecker({ installedVersion = "1.0.0.0", response } = {}) {
  const listeners = new Map();
  const storage = new Map();
  const dot = {
    dataset: {},
    title: "",
    attributes: {},
    setAttribute(name, value) { this.attributes[name] = value; }
  };
  const document = {
    readyState: "complete",
    getElementById(id) { return id === "digi-update-status" ? dot : null; },
    addEventListener() {}
  };
  const window = {
    DigiVersionComparison,
    setTimeout,
    clearTimeout,
    setInterval() { return 1; },
    addEventListener(name, callback) {
      if (!listeners.has(name)) listeners.set(name, new Set());
      listeners.get(name).add(callback);
    },
    removeEventListener(name, callback) {
      if (listeners.has(name)) listeners.get(name).delete(callback);
    },
    dispatchEvent(event) {
      for (const callback of listeners.get(event.type) || []) callback(event);
    },
    digiBackend: {
      state(callback) {
        callback(JSON.stringify({ version: installedVersion }));
      },
      checkReleaseManifest() {
        window.dispatchEvent({
          type: "digi-release-manifest",
          detail: JSON.stringify(response)
        });
      }
    }
  };
  const localStorage = {
    getItem(key) { return storage.has(key) ? storage.get(key) : null; },
    setItem(key, value) { storage.set(key, String(value)); },
    removeItem(key) { storage.delete(key); }
  };
  const context = { window, document, localStorage, Date, Promise, JSON, String, Error };
  vm.runInNewContext(checkerSource, context, { filename: "update_checker.js" });
  await new Promise(resolve => setImmediate(resolve));
  return { dot, storage };
}

function manifest(overrides = {}) {
  return {
    product: "Digi",
    schema_version: 1,
    release_status: "published",
    latest_version: "1.1.0.0",
    ...overrides
  };
}

test("integration: newer published release sets update status and pending version", async () => {
  const { dot, storage } = await runChecker({
    response: { ok: true, manifest: manifest() }
  });
  assert.equal(dot.dataset.status, "update");
  assert.equal(storage.get("digi.updateChecker.pendingVersion"), "1.1.0.0");
});

test("integration: same version sets current status and clears pending version", async () => {
  const { dot, storage } = await runChecker({
    response: { ok: true, manifest: manifest({ latest_version: "1.0.0.0" }) }
  });
  assert.equal(dot.dataset.status, "current");
  assert.equal(storage.has("digi.updateChecker.pendingVersion"), false);
});

test("integration: unpublished newer release does not offer an update", async () => {
  const { dot, storage } = await runChecker({
    response: { ok: true, manifest: manifest({ release_status: "unpublished" }) }
  });
  assert.equal(dot.dataset.status, "current");
  assert.equal(storage.has("digi.updateChecker.pendingVersion"), false);
});

test("integration: invalid metadata sets failure status", async () => {
  const { dot } = await runChecker({
    response: { ok: true, manifest: manifest({ schema_version: 99 }) }
  });
  assert.equal(dot.dataset.status, "offline");
});

test("integration: failed manifest request sets failure status", async () => {
  const { dot } = await runChecker({
    response: { ok: false, manifest: null }
  });
  assert.equal(dot.dataset.status, "offline");
});
