# Digi Update Checker

This folder contains the isolated update-status checker. It is deliberately separate from Digi's existing application functions.

## Scope

- Read the public `latest.json` release manifest.
- Compare numeric version components against the installed application version.
- Set the header status dot to green when no newer published version is available, red when a newer published version is found, and grey when the check cannot be trusted.
- Remember a detected version so a prompt can be shown on the next launch.
- Link to the release repository for details.

## Explicit non-goals

The checker does **not** download packages, install updates, modify application code, delete files, move or replace existing functions, or touch Digi user documents/settings. It does not perform an automatic downgrade.

The prompt is informational only. Actual update installation is intentionally not implemented here.

## Release source

`https://raw.githubusercontent.com/ananas123123/digiwebversionreleases/main/latest.json`

The release repository currently marks its stable channel as unpublished. Until a real release is published, a valid manifest means there is no published update to offer.

## Polling

The checker currently polls once per second as requested. This creates a continuous request to the public release metadata endpoint while Digi is open; if this proves noisy or rate-limited, increase `CHECK_INTERVAL_MS` in `update_checker.js`.
