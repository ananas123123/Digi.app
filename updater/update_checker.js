/* Digi update checker.
 * Reads public release metadata and updates only its own status indicator/dialog.
 * It never downloads, installs, removes, or modifies application/user files.
 */
(() => {
  "use strict";

  const LATEST_URLS = [
    "https://raw.githubusercontent.com/ananas123123/digiwebversionreleases/main/latest.json",
    "https://api.github.com/repos/ananas123123/digiwebversionreleases/contents/latest.json?ref=main"
  ];
  const RELEASES_URL = "https://github.com/ananas123123/digiwebversionreleases/releases";
  const CURRENT_VERSION = "1.0.0.0";
  const PENDING_KEY = "digi.updateChecker.pendingVersion";
  const CHECK_INTERVAL_MS = 60000;
  const REQUEST_TIMEOUT_MS = 10000;

  let lastRemoteCheck = 0;
  let requestInProgress = false;

  function compareVersions(left, right) {
    const a = String(left).split(".");
    const b = String(right).split(".");
    if (a.length !== b.length || !a.length) return null;
    const valid = value => value.every(part => /^\\d+$/.test(part));
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

  async function fetchManifest(url) {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
    try {
      const response = await fetch(url, {
        method: "GET",
        cache: "no-store",
        mode: "cors",
        signal: controller.signal,
        headers: { "Accept": "application/json" }
      });
      if (!response.ok) throw new Error("HTTP " + response.status);
      if (url.includes("api.github.com")) {
        const file = await response.json();
        if (!file || typeof file.content !== "string" || file.encoding !== "base64") {
          throw new Error("GitHub API returned an unexpected file format.");
        }
        return JSON.parse(atob(file.content.replace(/\\s/g, "")));
      }
      return await response.json();
    } finally {
      window.clearTimeout(timeout);
    }
  }

  async function checkRemoteStatus() {
    if (requestInProgress || Date.now() - lastRemoteCheck < CHECK_INTERVAL_MS) return;
    requestInProgress = true;
    lastRemoteCheck = Date.now();
    try {
      let manifest = null;
      let lastError = null;
      for (const url of LATEST_URLS) {
        try {
          manifest = await fetchManifest(url);
          break;
        } catch (error) {
          lastError = error;
        }
      }
      if (!manifest) throw lastError || new Error("Release metadata unavailable.");
      if (manifest.product !== "Digi" || manifest.schema_version !== 1) {
        throw new Error("Release metadata schema is not supported.");
      }

      if (manifest.release_status !== "published" ||
          typeof manifest.latest_version !== "string" ||
          !manifest.latest_version.trim()) {
        setStatus("current", "No published Digi update is available.");
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
          // Storage is optional; the status indicator still works without it.
        }
        return;
      }

      setStatus("current", relation === 0
        ? "Digi is up to date."
        : "The published release is older than this installation; no downgrade will be suggested.");
    } catch (_) {
      setStatus("unknown", "Update status unavailable. Could not reach or read the release repository.");
    } finally {
      requestInProgress = false;
    }
  }

  function start() {
    const dot = document.getElementById("digi-update-status");
    if (!dot) return;

    try {
      const pending = localStorage.getItem(PENDING_KEY);
      if (pending && compareVersions(pending, CURRENT_VERSION) === 1) {
        showPendingUpdate(pending);
      }
    } catch (_) {
      // Storage is optional; never interfere with Digi if unavailable.
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
