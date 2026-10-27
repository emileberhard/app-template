# Architecture

## Goals

- One SwiftUI app for iPhone and iPad that ships from a pushed tag to a
  prepared App Store version with no manual step before App Review.
- Logic that another client could reuse lives in Core and builds on Linux.

## Decisions

- **JSON Xcode project, no generator.** Xcode 27.2 writes `project.xcproj` by
  default. It diffs and edits as plain JSON, and synchronized folders pick up
  new files, so a generator such as Tuist would add a tool without adding a
  benefit.
- **Core as a Foundation-only package.** The app's rules test in seconds on
  Linux, and an Android (Swift SDK for Android), web (Wasm) or server client can
  reuse them. A tracer path, the days left in the year, runs through Core from
  the start.
- **Cloud signing.** Releases archive unsigned and export with an App Store
  Connect key, so CI holds no certificate or profile. `entitlements.json` says
  what each bundle claims, and the release checks the export against it.
- **Hosted release runners.** Signing and uploads run on GitHub's macOS
  runners. A private repository compiles CI on its own Mac runner to save
  billed minutes, and fails rather than fall back to them.
- **One Xcode pin.** `.xcode-version` names the Xcode for CI and the release;
  `select-xcode` fails on a runner without it, so CI never passes on a
  different compiler from the release's.
- **Admission before credentials.** `testflight` holds the App Store Connect
  key and runs the tag's build scripts, so it starts only after `admit` has
  checked the tag; within one job, a later step is no boundary against code an
  earlier one ran. Tagging a commit whose CI has already passed makes admission
  take seconds. An unprivileged archive job handing its archive to the
  privileged one would overlap the CI wait at the cost of an artifact transfer;
  measure that before adding it.
- **Screenshots from the app.** `capture` launches a Debug build in the
  simulator with `STARTER_CAPTURE` set; the app snapshots its own window once it
  is on screen and exits, so captures never race the launch and never drift
  from the UI.

Record each later decision here with the alternatives it beat.

## Expensive to change

- The bundle ID, once the App Store Connect app record exists.
- The folder names `Core` and `Apple`, once other clients or workflows depend
  on them.
