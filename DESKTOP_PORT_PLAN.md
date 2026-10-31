# Desktop continuation from updated main

Prepared 2026-10-30 after reviewing the upstream 2.x merge and the desktop prototype.

## Repository state

- New working branch: `codex/desktop-main-port`.
- Base: `main` / `origin/main`, `6a373b2df83d22ec1ba633648f57e242ce317644`.
- Preserved prototype: `feat/desktop-astra`, `398547ff7d8bb58bbad31bf6af60a3be952255be`.
- Original working tree was clean. Local main was fast-forwarded to the fetched fork's main.
- No rebase, cherry-pick, new commit, or push was performed. This report is an uncommitted file on the new branch. App sources remain identical to main.

## Decision: selectively port onto main

The update contains 101 commits beyond the old local main and changes 162 files (40,559 insertions, 9,305 deletions). It includes upstream's native macOS work, a directory reorganisation, new photo/species features, and major changes to the data store and navigation.

The desktop branch adds four commits over the old main. Replaying them wholesale would combine obsolete compatibility fixes and app ownership assumptions with the newer implementation. No rebase was attempted; this is an architectural assessment, not a claim that Git cannot merge the files. Use the fresh branch and transplant individual behaviours instead of replacing upstream files.

## Preserve from main

- Native universal macOS/iOS target configuration, including current widget support and pinned dependencies.
- `BlueDive/App/BlueDiveApp.swift`: window restoration, menu commands, language handling, and current model container setup.
- `BlueDive/App/MainTabView.swift`: application lifecycle, external-open handling, and background feeders.
- `BlueDive/Data & Sync/DiveDataFeeder.swift`: sole owner of the Dive query. Do not restore the prototype's query ownership in ContentView.
- `DiverSourcesFeeder` and `RemoteChangeFeeder`, including their mounting independent of the active tab.
- Current DiveStore caches, remote-deletion protections, notes search, filtering, and scoped updates.
- Existing macOS keyboard selection/profile preview and the current detail content, including Photos and Marine Life tabs.
- Current models, import/export code, photo storage, and species features. Do not replace these with older branch versions.
- `Shared/PlatformCompat.swift`, standard sheet presentation and locale propagation; avoid restoring obsolete platform workarounds.

## Port inventory

| Prototype feature | Current main | Action |
| --- | --- | --- |
| Native Mac target and platform compatibility | Already supplied upstream | Keep main; do not replay the old project settings or icon/calculator fixes. |
| Sidebar, sortable table, persistent adjacent detail | Main uses top-level tabs and a list/profile preview, opening details separately | Rework the desktop logbook against the current ContentView and store; retain shared detail content. |
| Keep detail tab when selecting another dive | Main's previous/next navigation retains local tab state; opening a new detail view starts a new state | Port parent-owned tab selection when adding the persistent detail pane, including the new Photos and Marine Life cases. |
| Isolated in-memory Debug test mode | Prototype-only implementation | Adapt first, using main's current schema and startup paths; isolate preferences, CloudKit, widget writes and other launch side effects. |
| Seconds-capable timestamp editor | Prototype AppKit control | Audit the current editor and port only if still needed; opening/cancelling must leave the timestamp untouched. |
| Recorded-sample chart inspection | Main still has a synthetic interpolated cursor and Catmull-Rom rendering | Reapply recorded-sample inspection carefully to the current chart; do not revert new chart/decompression features. |
| Side-by-side import review, fixed action footer, Escape | Prototype layout | Adapt the current review views with narrow-window fallback and current sheet/localisation helpers. |
| Local-file access fallback | Prototype changed selected-file access handling | Compare current handler before applying; a false security-scope return alone must not reject an otherwise readable file. |
| Personal signing overrides and schemes (`0c753b9`) | Machine-specific prototype setup | Do not cherry-pick. Provide a clearly isolated local Debug testing configuration separately. |
| Added translations (`77d1fc1`) | Catalog has changed extensively | Reuse current keys; extract and translate only missing keys through Scripts/xcstrings.py. Never replace the catalog. |

Prototype references: `bb3c364` (initial desktop work), `77d1fc1` (translations), `0c753b9` (personal signing), `398547f` (tab persistence). The old `DESKTOP_DEVELOPMENT.md` remains available on `feat/desktop-astra`; its build and data-ownership statements do not describe current main.

## Ordered implementation milestones

### 1. Establish a safe baseline and testing configuration

1. Build current main for native macOS and iOS Simulator using its current package pins. Do not reuse the old temporary build mirror or old libdc package revision.
2. Adapt Debug-only in-memory launch mode to the current schema. Keep the production container, entitlements and Release behaviour intact.
3. Audit current startup services (CloudKit, widget writes, reminders, weather, taxonomy, backup/history) so a validation run neither touches the normal logbook nor initiates unintended external work.
4. Document an Xcode UI workflow for local unsigned testing and the separate requirements for signed iCloud/Bluetooth testing.

Acceptance: both builds pass; the validation app starts without a provisioning-dependent CloudKit request; imports are disposable; quitting loses only test records.

### 2. Restore the desktop logbook workspace

1. Integrate the sortable date/site/depth/location/diver table and a resizable detail pane within the current logbook, retaining current search, diver filters, import/export and editing actions.
2. Keep table selection and detail tab in the parent presentation state. Recreate per-dive detail state when selection changes, passing the retained tab; never carry a pending edit or tank selection across dives.
3. Resolve selected objects through the current store and guard deleted/detached models before reading them. Clear stale detail selection when filtering or remote deletion removes a row.
4. Keep all background feeders mounted. Do not add a Dive query to ContentView or a desktop view.
5. Add sidebar navigation only after verifying destinations, menu actions and feeders remain correct; preserve current iOS behaviour.

The upstream CLAUDE.md prefers a shared UI with limited density adaptations. The user's explicit desktop workspace request is the scope for this layout work; keep platform branches local and reuse the current content rather than duplicating whole screens.

Acceptance: mouse and keyboard selection update the correct dive; sort/filter changes remain coherent; tab selection survives switching dives; Photos/Marine Life work; narrow-window, light/dark and language-override checks pass; iOS still builds.

### 3. Restore desktop precision and review improvements

- Inspect actual recorded samples, retaining missing readings and original sample times. No invented/interpolated tooltip values.
- Preserve timestamp seconds in editing and on cancellation.
- Use side-by-side import review on wide windows, with reachable complete lists and fixed actions; preserve the existing duplicate decisions and data-processing logic.
- Validate current examples using disposable data and unchanged source-file checksums. Check semantic values and unit metadata, not just imported counts.

Acceptance: real sample values and timestamps match the source/model; cancelling review does not add records; no model or import/export changes are introduced incidentally.

## Data-integrity constraints and open issues

- Do not modify data models, enum cases, properties or relationships as part of the port. Bringing in upstream through main is not permission to redesign them further.
- Do not normalise, convert or estimate imported/stored/exported dive values. Keep presentation-only formatting separate from stored data.
- The September examples exposed existing UDDF unit assumptions and whole-minute duration storage. At that time both files contained 60 dives / 48,751 samples, but the UDDF counterpart matched only 25 imported BlueDive dives. These are historical results and must be rechecked against the new main before drawing current conclusions.
- Address lossless data preservation as a separate, explicitly agreed change if the current model cannot represent the original values. Do not treat successful UI import as proof of a lossless round trip.

## Verification status of this continuation

Completed: fetched fork, reviewed history and implementation changes, fast-forwarded main, created clean continuation branch, preserved original desktop branch, and saved this plan.

Not performed in this continuation: app source porting, compilation, runtime testing, model changes, new commits or pushes. The earlier successful builds apply to the old desktop branch, not this new main-based branch.
