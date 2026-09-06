# Company Mac signing and release

The authoritative reference is [eidos-desktop-app-builder](https://github.com/eidos-agi/eidos-desktop-app-builder/tree/958661919e65bb8f066cdcee73a0e34293eaff1e), inspected September 6, 2026. In particular, see its [identity matrix](https://github.com/eidos-agi/eidos-desktop-app-builder/blob/958661919e65bb8f066cdcee73a0e34293eaff1e/accounts/apple-desktop-identities.md), [signing workflow](https://github.com/eidos-agi/eidos-desktop-app-builder/blob/958661919e65bb8f066cdcee73a0e34293eaff1e/docs/workflows/developer-id-and-notarize.md), and [credential custody](https://github.com/eidos-agi/eidos-desktop-app-builder/blob/958661919e65bb8f066cdcee73a0e34293eaff1e/docs/security/signing-and-secrets.md).

That repository records a company Developer ID certificate on `daniel-laptop-01` as of August 5, 2026:

- Identity: **Developer ID Application: Eidos AGI LLC (Y6CQ4SWPWM)**.
- Organization team: **Y6CQ4SWPWM**.
- Existing notary keychain profile: **eidos-notary** (credential availability is checked when executing).
- Certificate portal ID: **WX6CG24Y75**; recorded expiry February 1, 2027. Current validity and private-key availability must be checked in the actual keychain.

The private key and notary credential stay in their existing custody. Do not create or export a certificate, copy a `.p12`/`.p8`, or paste a password into chat/CI to run this product's build. This session has GitHub and a Linux authoring environment, but no connected execution path to that signing keychain. Therefore no notarized Clips artifact has been produced here.

## One command on the signing Mac

From a clean checkout of the intended Clips commit:

```sh
bash scripts/release-app.sh
```

If the configured local profile has a different name, set `CLIPS_NOTARY_PROFILE` to that **profile name**, not a password. The script checks the exact company identity, verifies access to the existing notary profile, runs tests, builds a staged app, signs with hardened runtime and the camera/microphone entitlements, submits to Apple, requires `Accepted`, staples and validates the ticket, and assesses the app with Gatekeeper. It then repacks the **stapled** app, unpacks that final ZIP and repeats staple/Gatekeeper checks before creating `dist/EidosClips-Notarized-<commit>.zip`.

The final ZIP has a SHA-256 file and source-linked evidence under `dist/release-<full-commit>/`. Nothing replaces an installed application. Installation and physical capture validation remain separate steps. Moving from the original ad-hoc prototype to Developer ID changes code identity; a one-time permission re-grant may be necessary.

## Development is a separate lane

`bash scripts/build-app.sh` produces **Eidos Clips Dev**, bundle ID `org.eidos.clips.dev`. Company releases retain `org.eidos.clips`. Ordinary GitHub CI contains no signing credentials and its artifact is explicitly named Development. A successful development build or code-signature integrity check is not Gatekeeper acceptance.

Do not hand out the earlier `EidosClips-macOS.zip` as an installable release. Its ad-hoc signature explains the reported Gatekeeper block. The release process must finish successfully before a notarized download is offered.

Apple references: [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime), [notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow), and [notarization troubleshooting](https://developer.apple.com/documentation/security/resolving-common-notarization-issues).
