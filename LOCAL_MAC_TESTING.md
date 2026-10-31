# Local Mac testing

On `codex/desktop-main-port`, choose the BlueDive scheme, My Mac destination, and Debug configuration in Xcode, then press Command-R.

Mac Debug builds disable code signing for the app, widget and test target. The app uses `app.bluedive.desktop.local`; the widget uses its `.widget` suffix. Release and iOS settings were not changed by this setup.

The local app uses an in-memory logbook, separate preferences, and no CloudKit account requests. It skips widget data writes and launch reminder scheduling. Imported or manually added dives disappear when the app quits. The normal logbook is not opened by this configuration. No extra launch arguments are needed.

This is for local UI testing, not iCloud, push-notification or widget integration testing. Those require a properly signed build with the relevant entitlements.

Verified 2026-10-30: built and launched from Xcode on My Mac; the app displayed its initial window with iCloud sync off. iOS and Release builds were not rerun for this setup.
