/* Digi update checker.
 * This module only reads public release metadata and updates its own status UI.
 * It never downloads, installs, removes, or modifies application/user files.
 */
(() => {
  "use strict";

  const LATEST_URL = "https://raw.githubusercontent.com/ananas123123/digiwebversionreleases/main/latest.json";
  const RELEASES_URL = "https://github.com/ananas123123/digiwebversionreleases/releases";
  const CURRENT_VERSION = "1.0.0.0";
  const PENDING_KEY = "digi.updateChecker.pendingVersion";
  const CHECK_INTERVAL_MS = 1000;
  const REQUEST_TIMEOUT_MS = 8000;

  let lastRemoteCheck = 0;
  let requestInProgress = false;
  let lastStatus = "unknown";

  function compareVersions(left, right) {
    const a = String(left).split(".");
    const b = String(right).split(".");
    if (a.length !== b.length || !a.length) return null;
    const valid = value => value.every(part => /^\d+$/.test(part));
    if (!valid(a) || !valid(b)) return null;
    for (let i = 0; i < a.length; i += 1) {
      const x = Number(a[i]);
      const y = Number(b[i]);
      if (x > y) return 1;
      if (x < y) return -1;
    }
    return 0;
  }

  function setStatus(status, title) {
    lastStatus = status;
    const dot = document.getElementById("digi-update-status");
    if (!dot) return;
    dot.dataset.status = status;
    dot.title = title;
    dot.setAttribute("aria-label", title);
  }

  function showPendingUpdate(version) {
    const dialog = document.getElementById("digi-update-dialog");
    const versionLabel = document.getElementById("digi-update-version");
    if (!dialog || !versionLabel) return;
    versionLabel.textContent = version;
    dialog.classList.remove("hidden");
    document.body.classList.add("digi-update-dialog-open");
    const later = document.getElementById("digi-update-later");
    const details = document.getElementById("digi-update-details");
    if (later) later.onclick = () => {
      dialog.classList.add("hidden");
      document.body.classList.remove("digi-update-dialog-open");
    };
    if (details) details.onclick = () => {
      window.open(RELEASES_URL, "_blank", "noopener,noreferrer");
    };
  }

  async function checkRemoteStatus() {
    if (requestInProgress) return;
    const now = Date.now();
    if (now - lastRemoteCheck < CHECK_INTERVAL_MS) return;
    requestInProgress = true;
    lastRemoteCheck = now;
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
    try {
      const response = await fetch(LATEST_URL, {
        method: "GET",
        cache: "no-store",
        mode: "cors",
        signal: controller.signal,
        headers: { "Accept": "application/json" }
      });
      if (!response.ok) throw new Error("Release metadata request failed.");
      const manifest = await response.json();
      if (manifest.product !== "Digi" || manifest.schema_version !== 1) {
        throw new Error("Release metadata schema is not supported.");
      }

      if (manifest.release_status !== "published" ||
          typeof manifest.latest_version !== "string" ||
          !manifest.latest_version.trim()) {
        setStatus("current", "Digi is up to date. No published update is available.");
        return;
      }

      const relation = compareVersions(manifest.latest_version, CURRENT_VERSION);
      if (relation === null) {
        setStatus("unknown", "Digi could not validate the published version.");
        return;
      }
      if (relation > 0) {
        setStatus("update", "Digi update available: " + manifest.latest_version);
        try {
          localStorage.setItem(PENDING_KEY, manifest.latest_version);
        } catch (_) {
          // The status indicator still works if browser storage is unavailable.
        }
        return;
      }

      setStatus("current", relation === 0
        ? "Digi is up to date."
        : "The published release is older than this installation; no downgrade will be suggested.");
    } catch (_) {
      setStatus("unknown", "Update status unavailable. Check your internet connection.");
    } finally {
      window.clearTimeout(timeout);
      requestInProgress = false;
    }
  }

  function start() {
    const dot = document.getElementById("digi-update-status");
    if (!dot) return;

    let pending = null;
    try {
      pending = localStorage.getItem(PENDING_KEY);
    } catch (_) {
      // Storage is optional; never interfere with Digi if unavailable.
    }
    if (pending && compareVersions(pending, CURRENT_VERSION) === 1) {
      showPendingUpdate(pending);
    }

    setStatus("unknown", "Checking for Digi updates…");
    checkRemoteStatus();
    window.setInterval(checkRemoteStatus, CHECK_INTERVAL_MS);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  } else {
    start();
  }
})();
