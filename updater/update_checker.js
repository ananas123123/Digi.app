/* Digi update checker.
 * Reads public release metadata and updates only its own status indicator/dialog.
 * It never downloads, installs, removes, or modifies application/user files.
 */
(() => {
  "use strict";

  const RELEASES_URL = "https://github.com/ananas123123/digiwebversionreleases/releases";
  const PENDING_KEY = "digi.updateChecker.pendingVersion";
  const CHECK_INTERVAL_MS = 60000;

  let lastRemoteCheck = 0;
  let requestInProgress = false;

  const compareVersions = window.DigiVersionComparison.compareVersions;

  function setStatus(status, title) {
    const dot = document.getElementById("digi-update-status");
    if (!dot) return;
    dot.dataset.status = status;
    dot.title = title;
    dot.setAttribute("aria-label", title);
  }

  function waitForBridge() {
    return new Promise((resolve, reject) => {
      const started = Date.now();
      const poll = () => {
        if (window.digiBackend &&
            typeof window.digiBackend.checkReleaseManifest === "function" &&
            typeof window.digiBackend.state === "function") {
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

  function readInstalledVersion(backend) {
    return new Promise((resolve, reject) => {
      const timeout = window.setTimeout(
        () => reject(new Error("Could not read Digi's installed version.")),
        5000
      );
      backend.state(raw => {
        window.clearTimeout(timeout);
        try {
          const state = JSON.parse(raw);
          const version = state && state.version;
          if (typeof version !== "string" || !/^\d+(\.\d+)*$/.test(version.trim())) {
            reject(new Error("Digi returned an invalid installed version."));
            return;
          }
          resolve(version.trim());
        } catch (_) {
          reject(new Error("Could not parse Digi's installed version."));
        }
      });
    });
  }

  function readManifest(backend) {
    return new Promise((resolve, reject) => {
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
  }

  async function checkRemoteStatus() {
    if (requestInProgress || Date.now() - lastRemoteCheck < CHECK_INTERVAL_MS) return;
    requestInProgress = true;
    lastRemoteCheck = Date.now();
    setStatus("checking", "Checking Digi's installed version and the latest release…");

    try {
      const backend = await waitForBridge();
      const currentVersion = await readInstalledVersion(backend);
      const response = await readManifest(backend);

      if (!response || !response.ok || !response.manifest) {
        throw new Error("Could not reach the release repository.");
      }

      const manifest = response.manifest;
      if (manifest.product !== "Digi" || manifest.schema_version !== 1) {
        throw new Error("Release metadata schema is not supported.");
      }

      const decision = window.DigiVersionComparison.evaluateRelease(currentVersion, manifest);
      if (decision.status === "invalid") {
        setStatus("offline", "Version comparison or release metadata validation failed.");
        return;
      }

      if (decision.status === "current") {
        const message = decision.reason === "unpublished"
          ? (typeof manifest.message === "string" && manifest.message.trim()
              ? manifest.message.trim()
              : "No published Digi update is currently available.")
          : decision.reason === "no-latest-version"
            ? "No latest version is published in latest.json."
            : "Installed Digi version: " + currentVersion + ". Release metadata is valid and no update is available.";
        setStatus("current", "Update check succeeded. " + message);
        try { localStorage.removeItem(PENDING_KEY); } catch (_) {}
        return;
      }

      setStatus("update", "RED: latest.json says " + decision.latestVersion + "; installed Digi version is " + currentVersion + ".");
      try {
        localStorage.setItem(PENDING_KEY, decision.latestVersion);
      } catch (_) {
        // Storage is optional; the status indicator still works without it.
      }
    } catch (error) {
      const reason = error && error.message ? error.message : "Unknown update-check error.";
      setStatus("offline", "GREY: update check failed. " + reason);
    } finally {
      requestInProgress = false;
    }
  }

  function start() {
    if (!document.getElementById("digi-update-status")) return;
    setStatus("checking", "Checking Digi's installed version and the latest release…");
    checkRemoteStatus();
    window.setInterval(checkRemoteStatus, CHECK_INTERVAL_MS);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  } else {
    start();
  }
})();
