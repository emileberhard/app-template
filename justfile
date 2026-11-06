# The Xcode that .xcode-version names, as CI and the release use; callers may explicitly override it.
export DEVELOPER_DIR := if os() == "macos" { shell('if [ -n "${DEVELOPER_DIR:-}" ]; then echo "$DEVELOPER_DIR"; else scripts/select-xcode; fi') } else { "" }

default:
    @just --list

test:
    swift test --package-path Core

build:
    xcodebuild -quiet -project Apple/Starter.xcodeproj -scheme Starter -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath .local/build -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build

screenshots:
    Apple/AppStore/capture app-store

[positional-arguments]
ui-previews *args:
    Apple/AppStore/capture previews "$@"

ui-previews-stop:
    Apple/AppStore/capture stop
