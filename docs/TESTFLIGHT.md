# Publishing

**CI does not publish.** There is no workflow that uploads to App Store Connect,
and no Apple credential is stored in this repository. Publishing is a manual step
from a machine with Xcode and the developer account signed in; the commit-time
workflow (`ci.yml`) only builds and tests.

Why: an upload needs a distribution identity, and an identity is a private key
Apple hands out once per certificate. Every arrangement that puts one in CI
either stores a long-lived secret (which has to be exported out of a keychain) or
re-creates the certificate per run (which mails the account holder and
invalidates profiles built on it). Neither is worth it for a handful of releases
a year.

## How to ship

__SHIP__

`project.yml` signs ad-hoc (`CODE_SIGN_IDENTITY: "-"`) so local builds need no
team. Submission needs a real one:

```sh
xcodegen generate
```

Then in Xcode set the team on the *Stitch* target (*Signing & Capabilities →
Automatically manage signing*), choose **Product → Archive**, and upload from the
Organizer. `AppStore/ExportOptions.plist` is the export setting to use.

Local `make build` / `make run` keep working because they never ask for a team.
