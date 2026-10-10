/* Version comparison and validation for the resolved latest.json -> directory.json -> version metadata protocol. */
(function (root, factory) {
  "use strict";
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.DigiVersionComparison = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  function compareVersions(left, right) {
    if (typeof left !== "string" || typeof right !== "string") return null;
    const a = left.trim().split(".");
    const b = right.trim().split(".");
    const valid = value =>
      value.length > 0 &&
      value.every(part => /^\d+$/.test(part) && Number.isSafeInteger(Number(part)));
    if (!valid(a) || !valid(b)) return null;
    const length = Math.max(a.length, b.length);
    for (let i = 0; i < length; i += 1) {
      const x = Number(a[i] ?? 0);
      const y = Number(b[i] ?? 0);
      if (x > y) return 1;
      if (x < y) return -1;
    }
    return 0;
  }

  function evaluateRelease(currentVersion, manifest) {
    if (typeof currentVersion !== "string" || compareVersions(currentVersion, currentVersion) === null ||
        !manifest || manifest.product !== "Digi" || manifest.schema_version !== 1) {
      return { status: "invalid" };
    }
    if (typeof manifest.latest_version !== "string" || !manifest.latest_version.trim()) {
      return manifest.release_status === "unpublished"
        ? { status: "current", reason: "unpublished-no-version" }
        : { status: "invalid", reason: "missing-latest-version" };
    }
    const latestVersion = manifest.latest_version.trim();
    const relation = compareVersions(latestVersion, currentVersion);
    if (relation === null) return { status: "invalid", reason: "invalid-version" };

    if (relation > 0) {
      return {
        status: "update",
        latestVersion,
        relation,
        packagePublished: manifest.release_status === "published"
      };
    }
    return { status: "current", latestVersion, relation };
  }

  /*
   * Validate package details before any future downloader is permitted to run.
   * This does not download a file or establish publisher identity.
   */
  function validatePackageMetadata(manifest) {
    if (!manifest || manifest.product !== "Digi" || manifest.schema_version !== 1) {
      return { valid: false, reason: "invalid-manifest" };
    }
    if (manifest.release_status !== "published") {
      return { valid: false, reason: "release-unpublished" };
    }
    const latest = manifest.latest_version;
    const release = manifest.release;
    if (typeof latest !== "string" || compareVersions(latest, latest) === null ||
        !release || typeof release !== "object" ||
        typeof release.version !== "string" ||
        compareVersions(release.version, latest) !== 0) {
      return { valid: false, reason: "release-version-mismatch" };
    }
    const pkg = release.package;
    if (!pkg || typeof pkg !== "object") {
      return { valid: false, reason: "missing-package" };
    }
    if (typeof pkg.file_name !== "string" || !pkg.file_name.trim() ||
        pkg.file_name !== pkg.file_name.split(/[\\\\/]/).pop()) {
      return { valid: false, reason: "invalid-package-filename" };
    }
    const extension = pkg.file_name.toLowerCase().split(".").pop();
    if (extension !== "exe" && !(extension === "txt" && pkg.kind === "test-fixture")) {
      return { valid: false, reason: "unsupported-package-file-type" };
    }
    if (typeof pkg.url !== "string") {
      return { valid: false, reason: "invalid-package-url" };
    }
    let parsed;
    try {
      parsed = new URL(pkg.url);
    } catch (_) {
      return { valid: false, reason: "invalid-package-url" };
    }
    if (parsed.protocol !== "https:" || !parsed.hostname ||
        parsed.username || parsed.password || parsed.hash) {
      return { valid: false, reason: "invalid-package-url" };
    }
    if (!Number.isSafeInteger(pkg.size_bytes) || pkg.size_bytes <= 0) {
      return { valid: false, reason: "invalid-package-size" };
    }
    if (typeof pkg.sha256 !== "string" || !/^[a-fA-F0-9]{64}$/.test(pkg.sha256)) {
      return { valid: false, reason: "invalid-package-sha256" };
    }
    return {
      valid: true,
      url: parsed.href,
      fileName: pkg.file_name,
      sizeBytes: pkg.size_bytes,
      sha256: pkg.sha256.toLowerCase(),
      version: latest.trim()
    };
  }

  return Object.freeze({ compareVersions, evaluateRelease, validatePackageMetadata });
});
