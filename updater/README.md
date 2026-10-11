# Digi Update Checker

This folder contains the isolated update-status checker. It is deliberately separate from Digi's existing application functions.

## Scope

- Read the public `latest.json` release manifest.
- Compare numeric version components against the installed application version.
- Set the header status dot to green when no newer version is announced, red when a newer version is found (including an unpublished announcement), and grey when the check cannot be trusted.
- Remember a detected version so a prompt can be shown on the next launch.
- Link to the release repository for details.

## Explicit non-goals

The checker does **not** download packages, install updates, modify application code, delete files, move or replace existing functions, or touch Digi user documents/settings. It does not perform an automatic downgrade.

The prompt is informational until a release is published and its package metadata is verified. Actual download and installation require a published release with valid version-specific metadata and a real package asset.

## Release source

The active release feed is the `web-releases` branch:

- `https://raw.githubusercontent.com/ananas123123/digiwebversionreleases/web-releases/latest.json`
- `https://raw.githubusercontent.com/ananas123123/digiwebversionreleases/web-releases/releases/directory.json`

A newer `unpublished` version should still turn the status indicator red and explain that the package is not available yet; it must not enable download or installation.

## Polling

The checker polls at the interval configured by `CHECK_INTERVAL_MS` in `update_checker.js`.
