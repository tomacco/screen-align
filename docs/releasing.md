# Releasing

## Cut a release

```bash
git tag v1.1.0
git push origin v1.1.0
```

The `Release` workflow runs the tests, builds a universal `ScreenAlign.app`, zips it and publishes a GitHub release with the zip and its SHA-256.

Then point the Homebrew cask at it:

```bash
scripts/update-cask.sh 1.1.0 ../homebrew-tap
cd ../homebrew-tap && git commit -am "screen-align 1.1.0" && git push
```

## Signing and notarization

Without the secrets below, the app is ad-hoc signed and users need right-click > Open on first launch. Once an Apple Developer account exists, add these repository secrets and the next release is signed with Developer ID, notarized and stapled:

| Secret | Value |
|--------|-------|
| `DEVELOPER_ID_P12` | The Developer ID Application certificate and key, exported as .p12, base64 encoded |
| `DEVELOPER_ID_P12_PASSWORD` | The password of that .p12 |
| `DEVELOPER_ID_IDENTITY` | The identity name, for example `Developer ID Application: Name (TEAMID)` |
| `APPLE_ID` | The Apple ID email used for notarization |
| `APPLE_TEAM_ID` | The 10-character team ID |
| `APPLE_APP_PASSWORD` | An app-specific password for that Apple ID |

After the first notarized release, remove the quarantine caveat from `scripts/screen-align.rb.template` and the right-click note from the README.
