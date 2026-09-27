#if os(macOS)
import SwiftUI
import Foundation

/// Navigation state is presentation-only; the shared logbook remains owned by ContentView.
struct DesktopSidebar: View {
    @Binding var selection: Int

    var body: some View {
        List(selection: Binding<Int?>(
            get: { selection },
            set: { if let destination = $0 { selection = destination } }
        )) {
            Section("Logbook") {
                Label("Dives", systemImage: "water.waves").tag(0)
                Label("Map", systemImage: "map").tag(1)
                Label("Trips", systemImage: "airplane").tag(4)
                Label("Statistics", systemImage: "chart.bar").tag(5)
                Label("Marine Life", systemImage: "fish").tag(6)
            }
            Section("Personal") {
                Label("Equipment", systemImage: "wrench.and.screwdriver").tag(2)
                Label("Documents", systemImage: "person.text.rectangle").tag(3)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("BlueDive")
    }
}

struct DesktopLogbookView: View {
    @Environment(DiveStore.self) private var store
    @Environment(\.locale) private var locale
    @Binding var selectedDiveID: UUID?
    @Binding var sortOrder: [KeyPathComparator<DiveSummary>]
    @State private var prefs = UserPreferences.shared

    private var rows: [DiveSummary] {
        sortOrder.isEmpty ? store.cachedFilteredSummaries : store.cachedFilteredSummaries.sorted(using: sortOrder)
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                diveTable
                Divider()
                HStack {
                    Text("Dives")
                    Spacer()
                    Text(verbatim: Double(store.cachedFilteredSummaries.count).localizedString(decimals: 0))
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
            }
            .frame(minWidth: 340, idealWidth: 480, maxWidth: 620, maxHeight: .infinity)

            Group {
                if let id = selectedDiveID, let dive = store.diveByID[id] {
                    // Selection belongs to the table. Do not enable the detail's independent
                    // swipe navigation, which would leave the highlighted row behind.
                    DiveDetailView(dive: dive, diveNumber: dive.diveNumber ?? 0)
                        .id(id)
                } else {
                    ContentUnavailableView("Select a dive", systemImage: "water.waves",
                        description: Text("Choose a dive in the logbook to view its details."))
                }
            }
            .frame(minWidth: 440, idealWidth: 650, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: store.sortOrder) { _, _ in sortOrder = [] }
        .onChange(of: store.cachedFilteredSummaries, initial: true) { _, summaries in
            if let selectedDiveID, !summaries.contains(where: { $0.id == selectedDiveID }) {
                self.selectedDiveID = nil
            }
        }
    }

    private var diveTable: some View {
        Table(rows, selection: $selectedDiveID, sortOrder: $sortOrder) {
            TableColumn("Date", value: \.timestamp) { summary in
                Text(summary.timestamp, format: .dateTime.year().month(.abbreviated).day().locale(locale))
            }
            .width(min: 100, ideal: 115)
            TableColumn("Site", value: \.siteName) { summary in
                Text(verbatim: summary.siteName.isEmpty ? "—" : summary.siteName)
                    .lineLimit(1)
                    .help(summary.siteName)
            }
            .width(min: 120, ideal: 170)
            TableColumn("Depth", value: \.displayMaxDepth) { summary in
                Text(verbatim: "\(summary.displayMaxDepth.localizedString(decimals: 1)) \(prefs.depthUnit.symbol)")
                    .monospacedDigit()
            }
            .width(min: 70, ideal: 85)
            TableColumn("Location", value: \.location) { summary in
                Text(verbatim: summary.location.isEmpty ? "—" : summary.location)
            }
            .width(min: 100, ideal: 130)
            TableColumn("Diver", value: \.diverName) { summary in
                Text(verbatim: summary.diverName.isEmpty ? "—" : summary.diverName)
            }
            .width(min: 90, ideal: 120)
        }
        .accessibilityLabel(Text("Dive logbook"))
        .overlay {
            if store.cachedFilteredSummaries.isEmpty {
                if store.dives.isEmpty {
                    ContentUnavailableView("No Dives", systemImage: "water.waves",
                        description: Text("Import dives or add a dive to begin your logbook."))
                } else {
                    ContentUnavailableView("No matching dives", systemImage: "line.3.horizontal.decrease",
                        description: Text("Change the search, diver, or filters to see more dives."))
                }
            }
        }
    }
}
#endif
