# TestFlight

[`.github/workflows/testflight.yml`](../.github/workflows/testflight.yml) archives
Stitch for iOS and macOS, exports both, and uploads them to TestFlight. It runs on
a GitHub `macos-26` runner: no machine of yours needs Xcode, a certificate, or an
Apple ID signed in.

## How it is triggered

| Trigger | What happens |
| --- | --- |
| Push a `v*` tag | archive, export and upload both platforms |
| *Actions → TestFlight → Run workflow* | the same, unless you untick **upload** — unticked it archives and exports without sending anything, which is the cheap way to check signing |

`CFBundleVersion` becomes the workflow run number, so TestFlight never sees the
same build number twice. `MARKETING_VERSION` is in `project.yml`; bump it there for
a new version.

## The six repository secrets

| Secret | Contents |
| --- | --- |
| `APPLE_TEAM_ID` | `B592D69P29` |
| `APP_CONNECT_KEY_ID` | the API key's 10-character ID |
| `APP_CONNECT_ISSUER_ID` | the issuer UUID shown above the key list |
| `APP_CONNECT_KEY_P8` | the whole `AuthKey_<id>.p8`, base64 encoded |
| `BUILD_CERTIFICATE_P12` | your *Apple Distribution* certificate, base64 encoded |
| `BUILD_CERTIFICATE_PASSWORD` | the password you chose when exporting the `.p12` |

The key comes from *App Store Connect → Users and Access → Integrations → App Store
Connect API*, role **App Manager**. Apple allows one download of the `.p8`.

The certificate comes from Keychain Access: *My Certificates → Apple Distribution: …
→ right-click → Export*. The runner imports it into a temporary keychain which is
thrown away with the machine.

```sh
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy     # paste into the secret
base64 -i distribution.p12      | pbcopy
```

Until all six exist the workflow fails at *Check the signing secrets exist* and
names the missing ones, on purpose: a deploy that cannot deploy should be red.

## Signing, and why the workflow overrides `project.yml`

`project.yml` signs ad-hoc (`CODE_SIGN_IDENTITY: "-"`, `CODE_SIGN_STYLE: Manual`) so
that `make build` and `make run` work with no developer team. That is right for a
Debug build and useless for the App Store. The workflow therefore overrides it on the
command line:

```
DEVELOPMENT_TEAM=$APPLE_TEAM_ID CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Distribution"
```

together with `-allowProvisioningUpdates` and the API key, which lets Xcode create or
refresh the provisioning profile it needs. Do not "fix" the workflow by editing
`project.yml` to automatic signing: that would break the local, team-less build.

## What it needs on Apple's side

- An app record for `com.ondrejli.stitch`, platform iOS **and** macOS, in App Store
  Connect. TestFlight rejects an upload with no record.
- The **App Sandbox** capability enabled for the bundle ID — the entitlement is
  already in [`Stitch/Resources/Stitch.entitlements`](../Stitch/Resources/Stitch.entitlements),
  but a capability has to be switched on for the identifier as well.

## Export options

[`AppStore/ExportOptions.plist`](../AppStore/ExportOptions.plist) is committed:
`method: app-store-connect`, `destination: export`, automatic signing for team
`B592D69P29`, symbols uploaded, `manageAppVersionAndBuildNumber` off. For iOS this
produces an `.ipa`, for macOS a `.pkg`; both are kept as workflow artifacts for 14
days so a failed upload can be retried without a rebuild.

## After the upload

App Store Connect processes the build for a few minutes before testers see it. The
first build of a version also needs the compliance answers — `ITSAppUsesNonExemptEncryption`
is already `false` in `project.yml`, so that is not one of them.
