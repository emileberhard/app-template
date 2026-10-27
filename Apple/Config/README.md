# Build and signing configuration

`Starter.xcconfig` owns shared Debug/Release settings. Copy
`Local.xcconfig.example` to `Local.xcconfig` for developer identity overrides.
Local commands use the selected Xcode (27.1 or later). Hosted workflows select
Xcode 27.1 explicitly. For private CI, `MAC_CI_RUNNER` is a JSON runner label or
label array; set `DEVELOPER_DIR` to that runner's Xcode path when it differs from
the hosted default. Release jobs always run on hosted `xcode-27`.

`entitlements.json` maps each archived app/extension path, relative to the main
app, to its repository-relative entitlement plist, or `null` for no capabilities.
The starter maps only `.` to `null`. Add entries when adding extensions; the
signing script rejects missing or stale entries. Sign children before parents.
Only `$(APP_BUNDLE_ID)` is substituted in entitlement files. Export must preserve
every required value exactly, with `aps-environment` changed to `production`.
Apple adds distribution identity entitlements during cloud signing.

Before the first release, create the App Store Connect app record and configure
the `testflight` environment with variables `DEVELOPMENT_TEAM`, `APP_BUNDLE_ID`
and secrets `APP_STORE_CONNECT_KEY`, `APP_STORE_CONNECT_KEY_ID`,
`APP_STORE_CONNECT_ISSUER_ID`. The key is the raw P8 private key. Register needed
capabilities and configure the app's export compliance and privacy disclosures.
The starter makes no encryption or privacy declarations on the app's behalf.
