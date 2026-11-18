# CLAUDE.md — Stitch

The map, not the manual. The [README](README.md) is unusually complete: it
documents every design decision, the annotation lifecycle and the layout, and it
is worth reading before changing rendering or history behaviour.
[`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md) covers shipping.

## What this is

A Skitch-like screenshot annotation app: paste or open one image, annotate it,
copy or save it back as a PNG. One SwiftUI codebase, macOS 26 and iOS/iPadOS 26,
over a platform-agnostic Swift Package. Published as **stitsch** in App Store
Connect; the code and file names keep the English spelling **Stitch**.

## Layout

```
project.yml                    XcodeGen spec — the source of truth; Stitch.xcodeproj is generated
StitchKit/                     platform-agnostic core (Swift Package, no AppKit/UIKit)
  Sources/StitchKit/
    Model/                     annotations, styles, tools, crop transform, stamps
    Canvas/                    CanvasBitmap — the mutable pixel surface
    Render/                    Renderer, CoreText text and stamp rasterisers
    History/                   dirty-rect patches, undo/redo stacks
    Tools/                     drag-to-annotation sessions, crop session
    Editing/                   ImageDocument (pixels + history), EditorModel (app state)
    Export/                    rotate/flip/crop, alpha modes, PNG encode/decode
  Tests/StitchKitTests/        171 tests
Stitch/                        SwiftUI app: Views/, Platform/ (pasteboard, file document), Commands/
AppStore/ExportOptions.plist   export settings used by the deploy workflow
.github/workflows/             ci.yml (tests + both builds); nothing publishes from CI
```

## Building and testing

**CI is the builder.** `.github/workflows/ci.yml` runs on `macos-26` for every push
and PR: `swift test` in `StitchKit`, then `xcodegen generate` and a Debug build for
macOS and for the iOS Simulator.

```sh
gh workflow run ci.yml
gh run watch
```

Required checks on `main`: **StitchKit tests**, **Build app (macOS + iOS)**. `main`
also rejects force pushes and deletions. There is no required reviewer, because the
project has one maintainer and GitHub will not let you approve your own PR.

Locally, with a full Xcode (the Makefile points `DEVELOPER_DIR` at
`/Applications/Xcode.app` when the Command Line Tools are selected):

```sh
make test          # StitchKit tests only; no Xcode project needed
make build         # macOS Debug build
make run           # build and launch
make install       # Release build into /Applications
```

`swift test` from `StitchKit/` works with the Command Line Tools installed; the app
targets need a full Xcode. Nothing here builds on Linux or on the VPS.

## Shipping

**Publishing is manual and CI does not do it.** Xcode, the team set on the *Stitch*
target, **Product → Archive**, upload from the Organizer — see
[`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md). Nothing Apple-related is stored in this
repository, and `project.yml`'s ad-hoc signing must stay as it is: changing it to fix
a signing error breaks `make build` for everyone without a team.

Build number = workflow run number; `MARKETING_VERSION` is in `project.yml`.

## Conventions

- Rendering and editing belong in `StitchKit` and must not import AppKit or UIKit.
  Platform code lives in `Stitch/Platform`.
- Every change to annotation geometry, history patches, crop maths or PNG export
  comes with a test — that is why the suite is 171 tests strong.
- `git` history: sentence-case commit subjects, body explains *why*, and the CI
  badge in the README is the claim that it builds.
- Licence is MIT deliberately: GPL cannot be submitted to the App Store.
