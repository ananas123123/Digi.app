/* Pure version comparison shared by Digi's updater and automated tests. */
(function (root, factory) {
  "use strict";
  const api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.DigiVersionComparison = api;
  }
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

    // Missing trailing components count as zero.
    const length = Math.max(a.length, b.length);
    for (let i = 0; i < length; i += 1) {
      const x = Number(a[i] ?? 0);
      const y = Number(b[i] ?? 0);
      if (x > y) return 1;
      if (x < y) return -1;
    }
    return 0;
  }

  return Object.freeze({ compareVersions });
});
