# Starter

Days left in the year, on iPhone and iPad.

`just build` compiles the app and `just test` tests its core; `just` lists the
rest. [AGENTS.md](AGENTS.md) describes the layout and the release.

## Template

This repository is the starting point for Emil Eberhard's Apple apps: a
buildable SwiftUI app with a portable Swift core, CI, and a release that takes
a pushed version tag through TestFlight to a prepared App Store version. To
start an app, create a repository from this template and rename `Starter`
everywhere, in file contents and paths. Licensed under the [MIT License](LICENSE).

## Dependency updates

Dependabot updates GitHub Actions. `Core` has no external packages, so it
needs no Swift updater. Add a Swift entry only for a declarative `Package.swift`
that declares remote dependencies and whose tools version Dependabot supports.
An Xcode project's `Package.resolved` alone is not a supported Swift manifest;
maintainers update those dependencies in Xcode and commit the project and lockfile.
