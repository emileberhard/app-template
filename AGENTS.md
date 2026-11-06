# Starter

Starter is a minimal iPhone and iPad app that shows the days left in the year.
Replace this paragraph with what the app is and who uses it, replace the
days-left screen and Core's tracer with the product's own, and keep the rest of
this file true as the app grows.

## Layout

| Path | Owns |
|---|---|
| `Core/` | `StarterCore`, the client-independent logic: Foundation only, tested on Linux in CI |
| `Apple/Starter.xcodeproj` | The Xcode project in the JSON `project.xcproj` format; edit it as JSON or in Xcode |
| `Apple/App/` | The app target's code and assets, a synchronized folder: new files need no project edit |
| `Apple/Config/` | `Starter.xcconfig` for build settings and identity, `entitlements.json`, `ExportOptions.plist` |
| `Apple/AppStore/` | `capture`, which records the App Store screenshots and the UI previews from the app itself, and optional `metadata/<locale>/*.txt` store text |
| `scripts/` | CI and release helpers: `select-xcode`, `sign-bundles` and `app-store-connect` |
| `.xcode-version` | The Xcode that CI and the release build with |
| `docs/architecture.md` | Goals, decisions and what is expensive to change |

- Core holds what another client would reuse and imports nothing
  platform-specific. The app depends on Core, never the reverse.
- Another client, such as Android, web or a server, becomes a sibling of
  `Apple/`. It reuses Core through the Swift SDK for Android, Wasm or Linux, or
  talks to it through a written contract.
- An extension is a target beside `App/`, with its entry in
  `Apple/Config/entitlements.json`; `sign-bundles` rejects a map that misses a
  bundle. Entitlement files may use `$(APP_BUNDLE_ID)` and nothing else.
- The app target serves iPhone and iPad. Add Mac only when the app ships there,
  together with its archive and screenshots in the release.
- Developer overrides go in the ignored `Apple/Config/Local.xcconfig` (start
  from `Local.xcconfig.example`); derived output goes in the ignored `.local/`.

## Commands

| Command | Does |
|---|---|
| `just` | List the recipes |
| `just test` | Test Core |
| `just build` | Compile the app for iOS without signing |
| `just screenshots` | Capture the App Store screenshots into `.local/screenshots/` |
| `just ui-previews [--appearance light|dark] [screen…]` | Render the app's screens, all by default, into `.local/ui-previews/` |
| `just ui-previews-stop` | Shut down the warm simulator when the UI work ends |

## UI previews

`just ui-previews` builds incrementally into `.local/simulator-build`, installs
into the shared warm simulator under its lock and takes real Simulator
screenshots. It prints JSON naming `sheet.jpg`, each screen's PNG and 900-pixel
JPEG, and the seconds spent building and capturing. Read every screen of the
sheet after each change; open a PNG only for detail. Pass screen IDs to select
a subset, or `--appearance light` to change the default dark appearance. App
Store captures use light. The driver pins the status bar and restores the
simulator appearance after capture.

- `CaptureScreen` in `Apple/App/Capture.swift` is the one catalog of screens.
  Give every main screen and state its case as it lands, such as empty, loaded
  and error. `APP_STORE_SCREENS` in `capture` picks the App Store screenshots.
- A case reaches the real screen through the app's root and navigation with
  deterministic fixtures: no network, clock, permission prompt or stored data.
  Freeze animated and clock-driven views. A screen that loads asynchronously
  signals readiness once its fixture is on screen. Present sheets as sheets.
- The app waits for matching drawn frames, signals the driver, loads its actual
  Simulator screenshot, then clears the root before the next case. Capture code
  compiles only in Debug. The capture build is ad-hoc signed, so the Keychain
  and other entitlement-backed APIs work in the Simulator. The driver owns and
  recreates its `.local/` output.
- A frame shows layout and rendering, including system chrome and sheets, but
  not interaction, animation, an extension's real host or performance; check
  those on a device.
- Keep a warm round within seconds. The JSON's timings show whether building
  or capturing grew. Run `just ui-previews-stop` when UI work ends.

## CI and release

CI tests Core on Linux, compiles the app and captures App Store screens on every
push to `main` and every pull request, with the Xcode `.xcode-version` names. A private repository
compiles on its own Mac runner, named by the `MAC_CI_RUNNER` variable as a JSON
label array, and fails without it, because hosted macOS minutes are billed; a
public one compiles hosted. The release signs and uploads on hosted runners; a
server on a machine of your own deploys from a job on that machine's runner. Builds use
only the package versions in the committed `Package.resolved`.

Pushing an annotated `MAJOR.MINOR.PATCH` tag on `main`, higher than every other
version tag, releases the app. The tag message lists the user-visible changes,
one short sentence per line; it becomes What to Test, What's New and the GitHub
release notes.

1. `admit` checks the tag and waits for CI on the same commit to pass;
   `numbers` then reserves an integer above the largest first component of all
   builds and pending uploads (one to three numeric components).
2. `testflight` uploads a new build at or above that reservation, beside any
   older build of the same version. After an earlier attempt began uploading,
   it waits up to 15 minutes for that attempt's build, at or above the
   reservation and with its full build number, and fails if none appears. It archives unsigned with
   the tag as `MARKETING_VERSION` and that `CURRENT_PROJECT_VERSION`, ad-hoc signs each
   embedded framework deepest first, then each app bundle with its entitlements,
   exports once through Xcode cloud signing without renumbering, checks the
   exported entitlements and every framework's distribution signature, and
   uploads exactly that export with `altool`. An
   existing build skips archiving, signing and uploading. Its build-number
   output makes both following App Store Connect jobs select that exact upload,
   including on retries.
   An app with a server waits for its deployed version where `release.yml`
   marks the spot.
3. `testflight-review` sets What to Test; when the app has external groups, it
   adds the build to them and submits it for beta review.
4. `app-store` captures the screenshots and prepares the App Store version with
   manual release and, once the app has a release, submits it for App Review. It waits for every screenshot placement
   to become active or reach a documented parent review state; unknown states
   keep waiting, and a timeout reports the last placement states.
   A newer tag withdraws an older version from review; before the app's
   first release, a version in review leaves preparation pending with a notice.
5. `github-release` publishes the release and marks it Latest only when its
   version is still the newest plain version tag, including on a later retry.

The first App Review submission and every App Store release stay manual. Rerun a
transiently failed job from the tag's own run, and only while that tag is still
the newest version; a fix ships as the next patch.

Before the first tag:

- Create the App Store Connect app record with its beta description, feedback
  email and review contact, and external TestFlight groups only for real
  external testers.
- Give the `testflight` environment, limited to version tags, the variables
  `DEVELOPMENT_TEAM` and `APP_BUNDLE_ID` and the secrets
  `APP_STORE_CONNECT_KEY` (the P8 file's contents), `APP_STORE_CONNECT_KEY_ID`
  and `APP_STORE_CONNECT_ISSUER_ID`.
- Register the capabilities the entitlements use, App Groups included, on the
  App IDs.
- `ITSAppUsesNonExemptEncryption = NO` in `Starter.xcconfig` declares that the
  app uses only exempt encryption. Change it when that stops being true.

## Template

This section applies only to
[app-template](https://github.com/emileberhard/app-template) itself; apps
created from it drop it. `Starter` is the placeholder that creation renames in
file contents and paths, so use it only where the app's name belongs. Keep the
template buildable, generic and free of product-specific code.
