/* Digi update checker.
 * Reads public release metadata and updates only its own status indicator/dialog.
 * It delegates download verification and installation to the Python backend and helper.
 */
(() => {
  "use strict";

  const RELEASES_URL = "https://github.com/ananas123123/digiwebversionreleases/releases";
  const PENDING_KEY = "digi.updateChecker.pendingVersion";
  const CHECK_INTERVAL_MS = 60000;

  let lastRemoteCheck = 0;
  let requestInProgress = false;
  let promptedVersion = "";
  let activeManifest = null;
  let downloadInProgress = false;
  let downloadResultConnected = false;
  let installResultConnected = false;
  let verifiedPackagePath = "";

  const compareVersions = window.DigiVersionComparison.compareVersions;

  function setStatus(status, title) {
    const dot = document.getElementById("digi-update-status");
    if (!dot) return;
    dot.dataset.status = status;
    dot.title = title;
    dot.setAttribute("aria-label", title);
  }


  function showUpdatePrompt(manifest, version, forceOpen = false) {
    if (!manifest || (promptedVersion === version && !forceOpen)) return;
    const validation = window.DigiVersionComparison.validatePackageMetadata(manifest);
    if (!validation.valid) return;
    activeManifest = manifest;
    promptedVersion = version;
    verifiedPackagePath = "";
    const dialog = document.getElementById("digi-update-dialog");
    const versionNode = document.getElementById("digi-update-version");
    const progress = document.getElementById("digi-update-progress");
    const download = document.getElementById("digi-update-details");
    const later = document.getElementById("digi-update-later");
    if (!dialog || !versionNode || !progress || !download || !later) return;
    versionNode.textContent = version;
    progress.hidden = true;
    progress.textContent = "";
    download.disabled = false;
    later.disabled = false;
    download.textContent = "Download update";
    dialog.classList.remove("hidden");
  }

  function closeUpdatePrompt() {
    const dialog = document.getElementById("digi-update-dialog");
    if (dialog) dialog.classList.add("hidden");
  }

  function displayDownloadResult(raw) {
    let result;
    try { result = JSON.parse(raw); } catch (_) {
      result = { ok: false, verified: false, message: "Digi returned an invalid download result." };
    }
    const progress = document.getElementById("digi-update-progress");
    const download = document.getElementById("digi-update-details");
    const later = document.getElementById("digi-update-later");
    if (!progress || !download || !later) return;
    downloadInProgress = false;
    progress.hidden = false;
    if (result.ok && result.verified && typeof result.path === "string" && result.path) {
      verifiedPackagePath = result.path;
      progress.textContent = "Download complete. Size and SHA-256 verified. Select Install update to replace the application safely.";
      download.disabled = false;
      download.textContent = "Install update";
    } else {
      verifiedPackagePath = "";
      progress.textContent = "Download rejected: " + (result.message || "verification failed") + " No installation was performed.";
      download.disabled = false;
      download.textContent = "Retry download";
    }
    later.disabled = false;
  }

  function displayInstallResult(raw) {
    let result;
    try { result = JSON.parse(raw); } catch (_) {
      result = { ok: false, message: "Digi returned an invalid installation result." };
    }
    const progress = document.getElementById("digi-update-progress");
    const download = document.getElementById("digi-update-details");
    const later = document.getElementById("digi-update-later");
    if (!progress || !download || !later) return;
    downloadInProgress = false;
    progress.hidden = false;
    if (result.ok) {
      download.disabled = true;
      later.disabled = true;
      download.textContent = "Installing…";
      progress.textContent = result.message || "Digi is closing to install the verified update.";
    } else {
      download.disabled = false;
      later.disabled = false;
      download.textContent = "Install update";
      progress.textContent = result.message || "The update helper could not be started. No installation was performed.";
    }
  }

  function connectDownloadResult(backend) {
    if (!backend) return;
    if (!downloadResultConnected && backend.packageDownloadResult) {
      backend.packageDownloadResult.connect(displayDownloadResult);
      downloadResultConnected = true;
    }
    if (!installResultConnected && backend.updateInstallResult) {
      backend.updateInstallResult.connect(displayInstallResult);
      installResultConnected = true;
    }
  }

  function bindPromptButtons() {
    const download = document.getElementById("digi-update-details");
    const later = document.getElementById("digi-update-later");
    const statusDot = document.getElementById("digi-update-status");
    if (later) later.onclick = closeUpdatePrompt;
    if (statusDot) {
      statusDot.title = "Check for Digi updates / open update prompt";
      statusDot.style.cursor = "pointer";
      statusDot.addEventListener("click", () => {
        if (activeManifest && promptedVersion) {
          showUpdatePrompt(activeManifest, promptedVersion, true);
        } else {
          checkRemoteStatus(true);
        }
      });
      statusDot.addEventListener("keydown", event => {
        if ((event.key === "Enter" || event.key === " ") && activeManifest && promptedVersion) {
          event.preventDefault();
          showUpdatePrompt(activeManifest, promptedVersion, true);
        }
      });
      statusDot.tabIndex = 0;
      statusDot.setAttribute("role", "button");
      statusDot.setAttribute("aria-label", "Open Digi update prompt");
    }
    if (download) download.onclick = async () => {
      if (downloadInProgress || !activeManifest) return;
      const validation = window.DigiVersionComparison.validatePackageMetadata(activeManifest);
      if (!validation.valid) {
        displayDownloadResult(JSON.stringify({ ok: false, verified: false, message: "Package metadata rejected: " + validation.reason }));
        return;
      }
      try {
        const backend = await waitForBridge();
        connectDownloadResult(backend);
        const progress = document.getElementById("digi-update-progress");
        if (verifiedPackagePath) {
          downloadInProgress = true;
          download.disabled = true;
          later.disabled = true;
          download.textContent = "Installing…";
          progress.hidden = false;
          progress.textContent = "Starting the separate updater. Digi will close and reopen after installation.";
          backend.installReleaseUpdate(JSON.stringify(activeManifest), verifiedPackagePath);
          return;
        }
        downloadInProgress = true;
        download.disabled = true;
        later.disabled = true;
        download.textContent = "Downloading…";
        progress.hidden = false;
        progress.textContent = "Downloading package to a temporary file…";
        backend.downloadReleasePackage(JSON.stringify(activeManifest));
      } catch (error) {
        downloadInProgress = false;
        displayDownloadResult(JSON.stringify({ ok: false, verified: false, message: error.message || "Digi backend unavailable." }));
      }
    };
  }

  function showTestModeBanner() {
    if (document.getElementById("digi-updater-test-banner")) return;
    const banner = document.createElement("div");
    banner.id = "digi-updater-test-banner";
    banner.setAttribute("role", "status");
    banner.textContent = "DEVELOPMENT TEST MODE — LOCAL UPDATE FEED — NO INSTALLS";
    Object.assign(banner.style, {
      position: "fixed", left: "12px", bottom: "12px", zIndex: "20000",
      padding: "9px 12px", border: "1px solid #e0b83e", borderRadius: "9px",
      background: "#29230f", color: "#ffe28a", font: "600 11px Segoe UI, Arial, sans-serif",
      letterSpacing: ".04em", boxShadow: "0 4px 20px rgba(0,0,0,.45)",
      pointerEvents: "none"
    });
    document.body.appendChild(banner);
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

  async function checkRemoteStatus(force = false) {
    if (requestInProgress || (!force && Date.now() - lastRemoteCheck < CHECK_INTERVAL_MS)) return;
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

      if (response.test_mode === true) showTestModeBanner();
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

      const announcementOnly = decision.packagePublished === false;
      setStatus("update", announcementOnly
        ? "RED: version " + decision.latestVersion + " has been announced, but its package is not yet published. Installed Digi version is " + currentVersion + ". No download or installation is available."
        : "RED: latest.json says " + decision.latestVersion + "; installed Digi version is " + currentVersion + ".");
      if (!announcementOnly) showUpdatePrompt(manifest, decision.latestVersion);
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
    bindPromptButtons();
    waitForBridge().then(connectDownloadResult).catch(() => {});
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
