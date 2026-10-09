/* Digi update checker.
 * Reads public release metadata and updates only its own status indicator/dialog.
 * It never downloads, installs, removes, or modifies application/user files.
 */
(() => {
  "use strict";

  const RELEASES_URL = "https://github.com/ananas123123/digiwebversionreleases/releases";
  const CURRENT_VERSION = "1.0.0.0";
  const PENDING_KEY = "digi.updateChecker.pendingVersion";
  const CHECK_INTERVAL_MS = 60000;

  let lastRemoteCheck = 0;
  let requestInProgress = false;

  function compareVersions(left, right) {
    const a = String(left).trim().split(".");
    const b = String(right).trim().split(".");
    if (!a.length || !b.length) return null;
    const valid = value => value.every(part => /^\d+$/.test(part));
    if (!valid(a) || !valid(b)) return null;

    // Compare numeric components; missing trailing components count as zero.
    const length = Math.max(a.length, b.length);
    for (let i = 0; i < length; i += 1) {
      const x = Number(a[i] ?? 0);
      const y = Number(b[i] ?? 0);
      if (x > y) return 1;
      if (x < y) return -1;
    }
    return 0;
  }

  function setStatus(status, title) {
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

  function waitForBridge() {
    return new Promise((resolve, reject) => {
      const started = Date.now();
      const poll = () => {
        if (window.digiBackend && typeof window.digiBackend.checkReleaseManifest === "function") {
          resolve(window.digiBackend);
        } else if (Date.now() - started > 8000) {
          reject(new Error("Digi backend bridge unavailable."));
        } else {
          window.setTimeout(poll, 100);
        }
      };
      poll();
    });
  }

  async function checkRemoteStatus() {
    if (requestInProgress || Date.now() - lastRemoteCheck < CHECK_INTERVAL_MS) return;
    requestInProgress = true;
    lastRemoteCheck = Date.now();
    setStatus("checking", "Checking the latest Digi version…");
    try {
      const backend = await waitForBridge();
      const response = await new Promise((resolve, reject) => {
        let settled = false;
        const timeout = window.setTimeout(() => {
          if (settled) return;
          settled = true;
          window.removeEventListener("digi-release-manifest", onResult);
          reject(new Error("Release repository request timed out."));
        }, 20000);
        const onResult = event => {
          if (settled) return;
          settled = true;
          window.clearTimeout(timeout);
          window.removeEventListener("digi-release-manifest", onResult);
          try {
            resolve(JSON.parse(event.detail));
          } catch (_) {
            reject(new Error("Invalid backend response."));
          }
        };
        window.addEventListener("digi-release-manifest", onResult);
        backend.checkReleaseManifest();
      });

      if (!response || !response.ok || !response.manifest) {
        throw new Error("Could not reach the release repository.");
      }
      const manifest = response.manifest;
      if (manifest.product !== "Digi" || manifest.schema_version !== 1) {
        throw new Error("Release metadata schema is not supported.");
      }

      // latest_version is the single source of truth for the dot.
      // A null/empty version means no version has been published yet.
      if (typeof manifest.latest_version !== "string" || !manifest.latest_version.trim()) {
        setStatus("current", "No newer Digi version is published.");
        return;
      }

      const latestVersion = manifest.latest_version.trim();
      const relation = compareVersions(latestVersion, CURRENT_VERSION);
      if (relation === null) {
        setStatus("offline", "Could not validate the latest Digi version.");
        return;
      }

      if (relation > 0) {
        setStatus("update", "Newer Digi version available: " + latestVersion);
        try {
          localStorage.setItem(PENDING_KEY, latestVersion);
        } catch (_) {
          // Storage is optional; the status indicator still works without it.
        }
      } else {
        setStatus("current", "Latest published version: " + latestVersion + ". Current Digi version: " + CURRENT_VERSION + ".");
        try {
          localStorage.removeItem(PENDING_KEY);
        } catch (_) {
          // Storage is optional.
        }
      }
    } catch (_) {
      setStatus("offline", "Update status unavailable. Could not reach the release repository.");
    } finally {
      requestInProgress = false;
    }
  }

  function start() {
    const dot = document.getElementById("digi-update-status");
    if (!dot) return;

    setStatus("checking", "Checking the latest Digi version…");
    checkRemoteStatus();
    window.setInterval(checkRemoteStatus, CHECK_INTERVAL_MS);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  } else {
    start();
  }
})();
