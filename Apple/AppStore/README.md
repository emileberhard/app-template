# Screenshots

`just screenshots` captures the app on temporary iPhone and iPad simulators into
`.local/screenshots/IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE/` and
`.local/screenshots/IPAD_PRO_3GEN_129/`. Replace the capture script with app-owned
scenes or composition when needed. Native JPEG captures have no alpha channel. The release uploads these sets to every existing
App Store localization. Add localized captures when the app needs them.

TestFlight distribution is app policy: `scripts/app-store-connect` attaches the
build to all existing external groups, following Lykta. Configure the intended
groups, beta description, feedback email and review contact before the first tag.
The script updates What to Test from the annotated tag message and never submits
the App Store version for App Review. An existing version in review leaves store
preparation pending with a notice.
