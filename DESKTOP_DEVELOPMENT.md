# Native desktop milestone

The BlueDive scheme supports native macOS 15.6 and later alongside iOS. The iOS widget extension remains restricted to iOS. Select **My Mac** in Xcode to build the native interface.

## Included

- A persistent sidebar with the existing logbook, map, trips, statistics, marine life, equipment, and documents destinations.
- A sortable dive table with date, site, depth, location, and diver columns.
- Resizable table and detail panes. Selection and table sort survive switching sidebar destinations; filtering out a selected record clears the detail pane.
- The existing detail tabs and editing/export actions, plus a native Settings window.
- A native timestamp editor with seconds. Displaying a timestamp does not assign a rounded value back to the model.
- Mac profile tooltips that select an actual recorded sample, retaining absent readings instead of interpolating them. Mac profile lines use linear rendering.

The desktop interface uses the existing `DiveStore` and `DiveSummary`. `ContentView` stays mounted as the sole dive-query owner while sidebar destinations change. No persisted model definitions, relationships, schema entries, or import/export algorithms were changed for this milestone.

## Isolated verification

For a Debug run, add `--ephemeral-logbook` to the scheme's launch arguments. This uses an in-memory SwiftData container with CloudKit disabled and suppresses CloudKit account requests, widget updates, and launch notification scheduling. Dive records disappear when that test process exits. Ordinary preferences still use the app's bundle identifier.

For a completely separate set of preferences, use the Debug-only validation bundle identifier `app.bluedive.desktop.validation`; it also automatically selects the in-memory mode. These options are ignored in Release builds.

Use copies of source files when checking import workflows. This mode exercises the existing parsers; it does not change or repair their interpretation of imported fields. Successful UI checks do not establish lossless round trips for every supported import/export format.

## Verification checklist

- Build the native Mac app for Apple Silicon and Intel, and build the iOS Simulator app and widget.
- Check empty logbooks, table sorting, keyboard selection, search, and empty search results.
- Select a dive, switch sidebar destinations, and return; the same dive should remain selected.
- Open and cancel the overview editor; the original timestamp's seconds should remain visible.
- Open Settings, resize the split panes, and inspect detail content at the minimum window width.
- Check the translation catalog with `Scripts/xcstrings.py check` after extracting new strings.

Bluetooth hardware, signed CloudKit sync, App Store distribution, large-logbook performance, and complete format round-trip testing require separate validation. This milestone does not claim those checks are complete.

## Desktop import review follow-up

The native Mac dive-duplicate review and equipment/document import previews now show new and duplicate records in separate, independently scrollable panes. All records are reachable without a five-row expansion control. Confirmation and cancellation stay outside the scrolling area; Escape cancels. The iOS layouts are unchanged.

Selected local files are read even when `startAccessingSecurityScopedResource()` returns false: the file may already be readable. A failed read reports the existing access error. Successful security-scoped grants are still released after reading. This changes file access only, not parsing or stored values.

Verified on 2026-09-27:

- Native macOS and iOS Simulator builds passed using the pinned local dependencies; the translation check passed (existing strings reused).
- A byte-identical temporary copy of the example BlueDive file imported 60 dives into the isolated in-memory app. Reopening it found 60 duplicates. Scrolling reached the last records, and Escape returned to the unchanged 60-dive logbook.
- The UDDF copy reached the split review with 25 duplicates and 35 new records. Cancel returned to 60 dives; the UDDF records were not committed.
- The dive review received visual verification. The generic equipment/document preview compiled on both platforms but was not separately exercised with equipment/document fixtures.

### Existing format limitations found in the examples

Both original files contain 60 dives and 48,751 profile samples. Dive numbers and order agree, as do the literal maximum-depth, average-depth, duration values and sample counts per dive. This is not proof of equivalent units or lossless import.

The BlueDive file includes mixed source units. For example, the Lock 21 record has maximum depth 57.6 with `distanceFormat` set to feet. The UDDF file contains the same literal depth 57.6; the existing UDDF parser treats it as metres. The exporter writes stored depth directly while assuming SI units. The existing UDDF parser also converts temperatures, pressures and volumes to metric storage units. These behaviours predate the desktop work and do not satisfy the project's strict no-conversion requirement.

The shared importer stores `duration / 60` in the whole-minute `Dive.duration` field. Of these 60 source durations, 53 have a nonzero seconds remainder. Profile sample times can retain seconds, and the existing `durationSeconds` helper prefers the final sample time, but that does not independently preserve the declared duration. An exact-preservation solution must be agreed before changing the model or unit conventions. No parser, exporter, or model changes were made in this follow-up.

Original example SHA-256 checksums, verified unchanged after testing:

- BlueDive: `d56b818479ee827f555c62d8fb5ec4f40809db14e35c09595d0d6f41c55cf036`
- UDDF: `43539230ba8c8a6dfbe648749cf0ee288ca1f8edade3e73eb8ad02933946b341`
