# Starter

Starter is a minimal iPhone and iPad app that shows the days left in the year.
Replace this paragraph with what the app is and who uses it, and keep the rest
of this file true as the app grows.

## Layout

| Path | Owns |
|---|---|
| `Core/` | `StarterCore`, the client-independent logic: Foundation only, tested on Linux in CI |
| `Apple/Starter.xcodeproj` | The Xcode project in the JSON `project.xcproj` format; edit it as JSON or in Xcode |
| `Apple/App/` | The app target's code and assets, a synchronized folder: new files need no project edit |
| `Apple/Config/` | `Starter.xcconfig` for build settings and identity, `entitlements.json`, `ExportOptions.plist` |
| `Apple/AppStore/` | `capture`, which records the App Store screenshots |
| `scripts/` | Release helpers: `sign-bundles` and `app-store-connect` |
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

## CI and release

CI tests Core on Linux and compiles the app on every push to `main` and every
pull request. A private repository compiles on its own Mac runner, named by the
`MAC_CI_RUNNER` variable as a JSON label array, because hosted macOS minutes
are billed; releases always run on hosted runners.

Pushing an annotated `MAJOR.MINOR.PATCH` tag on `main`, higher than every other
version tag, releases the app. The tag message lists the user-visible changes,
one short sentence per line; it becomes What to Test, What's New and the GitHub
release notes.

1. `admit` checks the tag and waits for CI on the same commit to pass.
2. `testflight` archives unsigned with the tag as `MARKETING_VERSION`, ad-hoc
   signs each bundle with its entitlements, exports through Xcode cloud signing,
   which assigns the build number, checks the exported entitlements and uploads.
   An app with a server waits for its deployed version where `release.yml`
   marks the spot.
3. `testflight-review` sets What to Test, adds the build to every external
   group and submits it for beta review.
4. `app-store` captures the screenshots and prepares the App Store version with
   manual release, short of App Review. A version still in review leaves it
   pending with a notice.
5. `github-release` publishes the release.

Submitting for App Review and releasing on the App Store stay manual. Rerun a
transiently failed job from the tag's own run; a fix ships as the next patch.

Before the first tag:

- Create the App Store Connect app record with its beta description, feedback
  email, review contact and external TestFlight groups.
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
