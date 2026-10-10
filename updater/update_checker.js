/* User-approved Digi updater UI.
 * A detected release is informational until the user explicitly chooses Update now.
 */
(() => {
  "use strict";

  const PENDING_KEY = "digi.updateChecker.pendingVersion";
  const DECLINED_KEY = "digi.updateChecker.declinedVersion";
  const PROMPTED_KEY = "digi.updateChecker.promptedVersion";
  const CHECK_INTERVAL_MS = 60000;

  let lastRemoteCheck = 0;
  let requestInProgress = false;
  let updateInProgress = false;
  let availableVersion = "";

  function compareVersions(left, right) {
    const pattern = /^\d+(?:\.\d+)*$/;
    if (typeof left !== "string" || typeof right !== "string" ||
        !pattern.test(left.trim()) || !pattern.test(right.trim())) return null;
    const a = left.trim().split(".").map(Number);
    const b = right.trim().split(".").map(Number);
    const length = Math.max(a.length, b.length);
    while (a.length < length) a.push(0);
    while (b.length < length) b.push(0);
    for (let i = 0; i < length; i += 1) {
      if (a[i] > b[i]) return 1;
      if (a[i] < b[i]) return -1;
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

  function setDialogMessage(message) {
    const copy = document.getElementById("digi-update-copy");
    if (copy) copy.textContent = message;
  }

  function setBusy(busy, message) {
    updateInProgress = busy;
    const yes = document.getElementById("digi-update-yes");
    const no = document.getElementById("digi-update-no");
    const progress = document.getElementById("digi-update-progress");
    if (yes) {
      yes.disabled = busy;
      yes.textContent = busy ? "Preparing update…" : "Yes, update";
    }
    if (no) no.disabled = busy;
    if (progress) progress.hidden = !busy;
    if (message) setDialogMessage(message);
  }

  function hideDialog() {
    const dialog = document.getElementById("digi-update-dialog");
    if (dialog) dialog.classList.add("hidden");
  }

  function showDialog(version, message) {
    const dialog = document.getElementById("digi-update-dialog");
    const versionNode = document.getElementById("digi-update-version");
    if (!dialog || !versionNode || updateInProgress) return;
    availableVersion = version;
    versionNode.textContent = version;
    setBusy(false, message || ("A newer stable version is available. Update only if you choose Yes."));
    dialog.classList.remove("hidden");
    try { sessionStorage.setItem(PROMPTED_KEY, version); } catch (_) {}
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
        () => reject(new Error("Could not read Digi's installed version.")), 5000
      );
      backend.state(raw => {
        window.clearTimeout(timeout);
        try {
          const state = JSON.parse(raw);
          const version = state && state.version;
          if (typeof version !== "string" || !/^\d+(?:\.\d+)*$/.test(version.trim())) {
            reject(new Error("Digi returned an invalid installed version."));
            return;
          }
          resolve({ version: version.trim(), frozen: !!state.is_frozen });
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
        try { resolve(JSON.parse(event.detail)); }
        catch (_) { reject(new Error("Invalid backend response.")); }
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
      const installed = await readInstalledVersion(backend);
      const response = await readManifest(backend);
      if (!response || !response.ok || !response.manifest) {
        throw new Error("Could not reach the release repository.");
      }
      const manifest = response.manifest;
      if (manifest.product !== "Digi" || manifest.schema_version !== 1) {
        throw new Error("Release metadata schema is not supported.");
      }
      if (manifest.release_status !== "published") {
        setStatus("current", "No published stable update is currently available.");
        try { localStorage.removeItem(PENDING_KEY); } catch (_) {}
        return;
      }
      const latest = manifest.latest_version;
      const relation = compareVersions(latest, installed.version);
      if (relation === null) throw new Error("The release version is invalid.");
      if (relation <= 0) {
        setStatus("current", "Digi is up to date. Installed: " + installed.version + ".");
        try {
          localStorage.removeItem(PENDING_KEY);
          localStorage.removeItem(DECLINED_KEY);
          sessionStorage.removeItem(PROMPTED_KEY);
        } catch (_) {}
        return;
      }

      setStatus("update", "A newer stable version is available: " + latest + ".");
      try { localStorage.setItem(PENDING_KEY, latest); } catch (_) {}
      if (!installed.frozen) {
        setStatus("update", "A newer release exists, but updates can only be installed from a packaged Digi build.");
        return;
      }
      let declined = "";
      let prompted = "";
      try {
        declined = localStorage.getItem(DECLINED_KEY) || "";
        prompted = sessionStorage.getItem(PROMPTED_KEY) || "";
      } catch (_) {}
      if (declined !== latest && prompted !== latest) {
        showDialog(latest, "A newer stable version is available. Digi will download and install it only if you choose Yes.");
      }
    } catch (error) {
      const reason = error && error.message ? error.message : "Unknown update-check error.";
      setStatus("offline", "Update check failed. " + reason);
    } finally {
      requestInProgress = false;
    }
  }

  function approveUpdate() {
    if (updateInProgress || !availableVersion) return;
    waitForBridge().then(backend => {
      if (typeof backend.startUpdate !== "function") {
        setDialogMessage("This Digi build does not contain the updater backend.");
        return;
      }
      setBusy(true, "Downloading and verifying the update. Digi will not change application files until the package has passed validation.");
      backend.startUpdate(availableVersion, accepted => {
        if (!accepted) {
          setBusy(false, "Digi could not start the update. No application files were changed.");
        }
      });
    }).catch(() => {
      setBusy(false, "Digi could not connect to its updater backend. No application files were changed.");
    });
  }

  function declineUpdate() {
    if (updateInProgress || !availableVersion) return;
    try { localStorage.setItem(DECLINED_KEY, availableVersion); } catch (_) {}
    hideDialog();
  }

  function onProgress(event) {
    if (!updateInProgress) return;
    const detail = event.detail || {};
    const progress = document.getElementById("digi-update-progress-fill");
    if (progress && Number.isFinite(Number(detail.percent))) {
      progress.style.width = Math.max(0, Math.min(100, Number(detail.percent))) + "%";
    }
    setDialogMessage(detail.message || "Preparing update…");
  }

  function onFinished(event) {
    const result = event.detail || {};
    if (result.ok) {
      setBusy(true, result.message || "Update helper started. Digi will close and restart.");
      setStatus("checking", "Digi is restarting to apply the approved update.");
      window.setTimeout(() => {
        if (window.digiBackend && typeof window.digiBackend.closeWindow === "function") {
          window.digiBackend.closeWindow();
        }
      }, 900);
      return;
    }
    setBusy(false, result.message || "The update failed. Your installed application was not changed.");
    const fill = document.getElementById("digi-update-progress-fill");
    if (fill) fill.style.width = "0%";
  }

  function start() {
    if (!document.getElementById("digi-update-status")) return;
    const yes = document.getElementById("digi-update-yes");
    const no = document.getElementById("digi-update-no");
    if (yes) yes.addEventListener("click", approveUpdate);
    if (no) no.addEventListener("click", declineUpdate);
    window.addEventListener("digi-update-progress", onProgress);
    window.addEventListener("digi-update-finished", onFinished);
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