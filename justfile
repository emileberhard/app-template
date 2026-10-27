default:
    @just --list

test:
    swift test --package-path Core

build:
    xcodebuild -quiet -project Apple/Starter.xcodeproj -scheme Starter -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath .local/build -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build

screenshots:
    Apple/AppStore/capture
