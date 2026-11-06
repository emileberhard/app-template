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
- **Sign nested frameworks before app bundles.** The unsigned archive can
  contain linker ad-hoc signatures or unsigned frameworks. Ad-hoc sign every
  embedded framework deepest first before sealing app bundles, including code
  inside extensions. Xcode's cloud export then replaces these signatures;
  reject the export unless every framework has an Apple Distribution authority.
  An entitlement check alone missed an invalid Sentry signature during Pingo's
  migration. Removing signatures instead leaves nested code unsigned before
  app signing, so it is not the shared signing path.
- **Hosted release runners.** Signing and uploads run on GitHub's macOS
  runners. A private repository compiles CI on its own Mac runner to save
  billed minutes, and fails rather than fall back to them.
- **One Xcode pin.** `.xcode-version` names the Xcode for CI and the release;
  `select-xcode` fails on a runner without it, so CI never passes on a
  different compiler from the release's.
- **Locked packages on clean runners.** Resolve the committed package versions
  before archiving; `-skipPackageUpdates` needs packages already fetched even
  with `-onlyUsePackageVersionsFromResolvedFile`.
- **Admission before credentials.** `testflight` holds the App Store Connect
  key and runs the tag's build scripts, so it starts only after `admit` has
  checked the tag; within one job, a later step is no boundary against code an
  earlier one ran. Tagging a commit whose CI has already passed makes admission
  take seconds. An unprivileged archive job handing its archive to the
  privileged one would overlap the CI wait at the cost of an artifact transfer;
  measure that before adding it.
- **One exact upload.** The `numbers` job reserves one above the largest
  first component across all uploaded builds and pending uploads, accepting
  Apple's one to three numeric components; a failed-jobs rerun keeps that
  reservation. The serialized TestFlight job injects a number at or above it
  into the archive,
  and disables Xcode's export renumbering. Both App Store Connect jobs consume
  the job output and filter that exact build. A first attempt always uploads,
  because App Store Connect can hold older builds of the same version (it
  treats 1.0 and 1.0.0 as one version). GitHub's step history fences any
  earlier attempt that started the upload: reuse its build, at or above the
  reservation with its full build number, and skip archiving, signing and
  uploading, or wait up to 15 minutes for Apple's list to show it, then fail
  rather than upload again.
  The upload has its own named step so a failed entitlement check creates no
  uncertainty. A stored fence artifact would expire and duplicate Apple's
  build inventory; selecting a fresh number on every retry could send testers
  a duplicate after a lost upload acknowledgement.
- **Upload the checked export.** One cloud-signed export is checked and
  uploaded with `altool`. Exporting again with `destination` `upload` signed
  a second time, about 2.5 minutes on hosted runners in RemoteCoder's iOS
  release, and shipped bytes nobody checked.
- **Owned screenshot reservations.** Every reserved image ID is queued before
  transfer. Uploads and placement share one cleanup scope; workers finish
  before cleanup deletes any unplaced reservations. This also covers failures
  during transfer, which previously escaped cleanup.
- **Confirm screenshot readiness.** Apple returns both the live `ACTIVE`
  placement state and the documented parent review states. Only those finish
  preparation; `FAILED` reports Apple's details, and every other state waits
  within the existing 40-minute bound, with the last states in a timeout.
  Treating every state except `ASSET_PROCESSING` as ready let a `PENDING`
  iPhone placement pass while its image was still processing.
- **Real Simulator screenshots, driven by the app.** The Debug capture root
  reaches each catalog case through the app's real root and navigation using
  deterministic fixtures. It waits for consecutive matching drawn frames and
  signals the driver, which captures the Simulator with its system chrome and
  presented sheets. The app loads the PNG and encodes the thumbnail concurrently
  while clearing the root before the next case. The driver pins the status bar,
  applies and restores appearance, bounds the handshake and terminates failed
  launches. In-app window snapshots omit system UI; UI tests add a runner and
  navigation overhead. This handshake keeps one catalog and one launch while
  preserving fidelity. Animated and clock-driven fixtures must be frozen;
  otherwise frame stability cannot prove readiness. A screen whose asynchronous
  data or sheet has not appeared yet must signal its own readiness first.
- **One warm simulator per Mac and device type.** `ui-previews` keeps one
  booted simulator for every app on the Mac that previews on the same device,
  identified by the UDID recorded in `~/Library/Caches/ui-previews/` rather
  than by name, and holds its lock only while installing and capturing. It
  replaces that simulator when a newer runtime for the device is installed.
  Builds and output stay in each checkout's `.local/`, so parallel worktrees
  build concurrently and never capture each other's app. A simulator per
  checkout would multiply booted simulators, each costing gigabytes of memory;
  one simulator for all device types would be recreated and cold-booted
  whenever apps on different devices alternate. The App Store screenshots
  still use fresh simulators deleted afterwards, so release images carry no
  development state. Runtimes are chosen among plain iOS runtimes only; a
  device-specific runtime also reports the iOS platform but cannot run other
  devices. An app that frames its slides with SwiftUI draws them through
  `ImageRenderer.render` into its own Core Graphics bitmap: on hosted runners
  `ImageRenderer.cgImage` returned fully transparent images in four of five of
  AgenTTY's CI captures.
- **Capture beside the build.** The release's `screenshots` job needs only
  `admit`, holds no credentials and hands its slides to `app-store` as an
  artifact, so App Review waits for neither a capture after TestFlight nor a Mac
  for the App Store Connect calls. It adds one hosted macOS job beside
  `testflight` for the length of a capture.
- **Freshness from the incremental build.** Every round runs `xcodebuild`
  instead of skipping it on a hash of chosen source files. Such a stamp misses
  inputs it does not list, such as the package lock, assets and the Xcode
  version, and returns stale screens. Resolve locked packages again when
  `Package.resolved` changes; a clean build also resolves them before building.

- **Store text from files.** Optional `Apple/AppStore/metadata/<locale>/*.txt`
  (description, keywords, promotional text, support URL, name, subtitle and
  privacy URL) is applied to the prepared version, sending only fields that
  differ; an app info that is no longer editable keeps its name, subtitle and
  privacy URL. Editing text in App Store Connect by hand would drift from the
  repository and be overwritten by nothing. AgenTTY carried this first.
- **Refuse a stale version before reserving.** `numbers` runs `check-version`,
  which rejects a version already released or below a released or uploaded
  one, before it reserves a build number, so a wrong tag fails before any
  upload.
- **One Xcode locally too.** The justfile exports the `DEVELOPER_DIR` that
  `select-xcode` finds for `.xcode-version` unless the caller sets one, so local
  recipes compile with the release's Xcode rather than whichever is selected.
  An app that keeps TestFlight distribution manual calls `what-to-test` instead
  of `testflight`.

Record each later decision here with the alternatives it beat.

## Expensive to change

- The bundle ID, once the App Store Connect app record exists.
- The folder names `Core` and `Apple`, once other clients or workflows depend
  on them.
