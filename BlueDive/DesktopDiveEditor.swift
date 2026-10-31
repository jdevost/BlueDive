#if os(macOS)
import SwiftUI
import SwiftData
import MapKit

/// Presentation-only drafts. Only fields the user changes are assigned on Save.
struct DesktopDiveEditor: View {
    let dive: Dive
    let tab: DiveTab
    @Binding var isEditing: Bool
    @Binding var draft: [String: String]
    var onMore: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(DiveStore.self) private var store
    @State private var saveError: String?
    @State private var invalidSiteNumber = false
    @State private var selectedSite: Dive?
    @State private var copyGPS = true
    @State private var pickingExit: Bool?
    @State private var mapPosition: MapCameraPosition = .automatic

    private static let textFields: [String: ReferenceWritableKeyPath<Dive, String>] = [
        "buddies": \.buddies, "siteName": \.siteName, "location": \.location, "notes": \.notes
    ]
    private static let optionalFields: [String: ReferenceWritableKeyPath<Dive, String?>] = [
        "diveOperator": \.diveOperator, "diveMaster": \.diveMaster,
        "skipper": \.skipper, "boat": \.boat, "tags": \.tags,
        "siteCountry": \.siteCountry, "siteBodyOfWater": \.siteBodyOfWater,
        "siteWaterType": \.siteWaterType, "siteDifficulty": \.siteDifficulty,
        "weather": \.weather, "current": \.current,
        "surfaceConditions": \.surfaceConditions, "visibility": \.visibility, "entryType": \.entryType
    ]

    private static let numericFields: [String: ReferenceWritableKeyPath<Dive, Double?>] = [
        "siteLatitude": \.siteLatitude, "siteLongitude": \.siteLongitude,
        "exitLatitude": \.exitLatitude, "exitLongitude": \.exitLongitude,
        "siteAltitude": \.siteAltitude
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tab.localizedName).font(.title2.bold())
                Spacer()
                if isEditing && tab != .notes && tab != .samples && tab != .siteDetails {
                    Button("More Edit Options", action: onMore)
                        .disabled(!draft.isEmpty)
                }
            }
            if isEditing {
                Text("Drafts stay with each dive while you switch. Save applies changes to this dive only.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if invalidSiteNumber {
                Text("Enter valid coordinates and altitude before saving.")
                    .foregroundStyle(.red)
            }
            if let saveError {
                Text(verbatim: saveError).foregroundStyle(.red).textSelection(.enabled)
            }
            if tab == .notes {
                if isEditing {
                    TextEditor(text: binding("notes"))
                        .font(.body)
                        .padding(8)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel(Text("Notes"))
                        .frame(minHeight: 240, maxHeight: .infinity)
                } else {
                    ScrollView {
                        Text(verbatim: draft["notes"] ?? dive.notes)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(8)
                    }
                    .frame(maxHeight: .infinity)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch tab {
                        case .menu:
                            field("Buddies", key: "buddies")
                            field("Dive Center", key: "diveOperator")
                            field("Guide/Instructor", key: "diveMaster")
                            field("Captain", key: "skipper")
                            field("Boat", key: "boat")
                            field("Tags", key: "tags")
                        case .siteDetails:
                            siteFields
                        case .conditions:
                            field("Weather", key: "weather")
                            field("Current", key: "current")
                            field("Surface Conditions", key: "surfaceConditions")
                            field("Visibility", key: "visibility")
                            field("Entry Type", key: "entryType")
                        case .samples:
                            Text("Samples come from your dive computer and cannot be manually edited.")
                        default:
                            Text("Use More Edit Options for measurements and tank settings.")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
            if !draft.isEmpty {
                Divider()
                HStack {
                    Text("Unsaved Changes").foregroundStyle(.secondary)
                    Spacer()
                    Button("Discard Changes") { draft = [:]; saveError = nil; invalidSiteNumber = false }
                    Button("Save Changes", action: save)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut("s", modifiers: .command)
                }
            }
        }
        .padding(20)
    }

    private func numberText(_ value: Double) -> String {
        // Shortest round-trippable representation; never pre-round stored coordinates.
        String(value).replacingOccurrences(of: ".", with: Locale.current.decimalSeparator ?? ".")
    }

    private func parsedNumber(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
    }

    private var sites: [Dive] {
        var seen = Set<String>()
        return store.dives.filter {
            $0.id != dive.id && !$0.siteName.isEmpty && seen.insert($0.siteName).inserted
        }
    }

    private var siteFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !sites.isEmpty {
                GroupBox("Copy from Existing Site") {
                    VStack(alignment: .leading, spacing: 10) {
                        SiteSearchField(selectedSite: $selectedSite, recents: Array(sites.prefix(3)),
                                        allSites: sites.sorted { $0.siteName.localizedCaseInsensitiveCompare($1.siteName) == .orderedAscending })
                        Toggle("Include GPS Coordinates (Entry & Exit)", isOn: $copyGPS)
                        Button("Copy Site Information") { if let selectedSite { copySite(selectedSite) } }
                            .disabled(selectedSite == nil)
                        Text("Altitude is copied only when both dives use the same stored distance unit.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(8)
                }
            }
            GroupBox("Location") {
                VStack(alignment: .leading, spacing: 12) {
                    field("Site Name", key: "siteName")
                    field("Country", key: "siteCountry")
                    field("Location", key: "location")
                    field("Difficulty", key: "siteDifficulty")
                    Menu("Difficulty") {
                        Button("—") { binding("siteDifficulty").wrappedValue = "" }
                        ForEach(EditSiteDetailsView.difficultyScale, id: \.level) { item in
                            Button {
                                binding("siteDifficulty").wrappedValue = String(item.level)
                            } label: {
                                Text("\(item.level) — \(Text(LocalizedStringKey(item.label)))")
                            }
                        }
                    }
                }.padding(8)
            }
            GroupBox("Water") {
                VStack(alignment: .leading, spacing: 12) {
                    field("Water Type", key: "siteWaterType")
                    Menu("Water Type") {
                        Button("—") { binding("siteWaterType").wrappedValue = "" }
                        Button("Freshwater") { binding("siteWaterType").wrappedValue = "Freshwater" }
                        Button("Saltwater") { binding("siteWaterType").wrappedValue = "Saltwater" }
                        Button("Brackish water (EN13319)") { binding("siteWaterType").wrappedValue = "EN13319" }
                    }
                    field("Body of Water", key: "siteBodyOfWater")
                }.padding(8)
            }
            GroupBox("GPS Coordinates (Entry)") {
                VStack(alignment: .leading, spacing: 12) {
                    field("Latitude", key: "siteLatitude")
                    field("Longitude", key: "siteLongitude")
                    HStack {
                        Button("Pick on Map") { beginPicking(exit: false) }
                        Button("Reset") { resetGPS(exit: false) }
                            .disabled(recordedCoordinate(exit: false) == nil)
                    }
                }.padding(8)
            }
            GroupBox("GPS Coordinates (Exit)") {
                VStack(alignment: .leading, spacing: 12) {
                    field("Latitude", key: "exitLatitude")
                    field("Longitude", key: "exitLongitude")
                    HStack {
                        Button("Pick on Map") { beginPicking(exit: true) }
                        Button("Same as Entry") {
                            binding("exitLatitude").wrappedValue = binding("siteLatitude").wrappedValue
                            binding("exitLongitude").wrappedValue = binding("siteLongitude").wrappedValue
                        }.disabled(coordinate(exit: false) == nil)
                        Button("Reset") { resetGPS(exit: true) }
                            .disabled(recordedCoordinate(exit: true) == nil)
                    }
                }.padding(8)
            }
            HStack(alignment: .bottom) {
                field("Altitude", key: "siteAltitude")
                Text(verbatim: dive.importDistanceUnit == "feet" ? "ft" : "m")
                    .foregroundStyle(.secondary).padding(.bottom, 5)
            }
            if let exit = pickingExit {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if exit { Text("Set Exit Coordinates") } else { Text("Set Entry Coordinates") }
                        Spacer()
                        Button("Close") { pickingExit = nil }
                    }
                    Text("Click the map to set coordinates in this dive’s draft.")
                        .font(.caption).foregroundStyle(.secondary)
                    MapReader { proxy in
                        Map(position: $mapPosition) {
                            if let entry = coordinate(exit: false) {
                                Marker("Entry", coordinate: entry).tint(.green)
                            }
                            if let exitPoint = coordinate(exit: true) {
                                Marker("Exit", coordinate: exitPoint).tint(.orange)
                            }
                        }
                        .onTapGesture { point in
                            guard let chosen = proxy.convert(point, from: .local) else { return }
                            setCoordinate(chosen, exit: exit)
                        }
                    }
                    .frame(height: 300)
                }
            }
        }
    }

    private func coordinate(exit: Bool) -> CLLocationCoordinate2D? {
        let prefix = exit ? "exit" : "site"
        guard let lat = parsedNumber(binding(prefix + "Latitude").wrappedValue),
              let lon = parsedNumber(binding(prefix + "Longitude").wrappedValue),
              lat.isFinite, lon.isFinite, (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func beginPicking(exit: Bool) {
        pickingExit = exit
        if let point = coordinate(exit: exit) ?? coordinate(exit: !exit) {
            mapPosition = .region(MKCoordinateRegion(center: point, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
        } else {
            mapPosition = .automatic
        }
    }

    private func setCoordinate(_ coordinate: CLLocationCoordinate2D, exit: Bool) {
        let prefix = exit ? "exit" : "site"
        binding(prefix + "Latitude").wrappedValue = numberText(coordinate.latitude)
        binding(prefix + "Longitude").wrappedValue = numberText(coordinate.longitude)
    }

    private func recordedCoordinate(exit: Bool) -> CLLocationCoordinate2D? {
        guard let data = dive.rawDiveComputerData else { return nil }
        if exit {
            guard let gps = ShearwaterPNFGPS.extractExitGPS(from: data) else { return nil }
            return CLLocationCoordinate2D(latitude: gps.latitude, longitude: gps.longitude)
        }
        guard let gps = ShearwaterPNFGPS.extractEntryGPS(from: data) else { return nil }
        return CLLocationCoordinate2D(latitude: gps.latitude, longitude: gps.longitude)
    }

    private func resetGPS(exit: Bool) {
        if let point = recordedCoordinate(exit: exit) { setCoordinate(point, exit: exit) }
    }

    private func copySite(_ source: Dive) {
        for key in ["siteName", "location"] {
            if let path = Self.textFields[key] { binding(key).wrappedValue = source[keyPath: path] }
        }
        for key in ["siteCountry", "siteBodyOfWater", "siteWaterType", "siteDifficulty"] {
            if let path = Self.optionalFields[key] { binding(key).wrappedValue = source[keyPath: path] ?? "" }
        }
        guard copyGPS else { return }
        for (key, path) in Self.numericFields {
            guard key != "siteAltitude" || source.importDistanceUnit == dive.importDistanceUnit else { continue }
            binding(key).wrappedValue = source[keyPath: path].map(numberText) ?? ""
        }
    }

    private func value(_ key: String) -> String {
        if let path = Self.textFields[key] { return dive[keyPath: path] }
        if let path = Self.optionalFields[key] { return dive[keyPath: path] ?? "" }
        if let path = Self.numericFields[key] { return dive[keyPath: path].map(numberText) ?? "" }
        return ""
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { draft[key] ?? value(key) }, set: { newValue in
            draft[key] = newValue == value(key) ? nil : newValue
            saveError = nil
            invalidSiteNumber = false
        })
    }

    private func field(_ label: LocalizedStringKey, key: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: binding(key))
                .textFieldStyle(.roundedBorder)
                .padding(.trailing, 26)
                .overlay(alignment: .trailing) {
                    Button { binding(key).wrappedValue = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Clear"))
                }
        }
    }

    private func save() {
        invalidSiteNumber = false
        // Validate every edited number before assigning any field. Empty explicitly clears it.
        for key in Self.numericFields.keys {
            guard let text = draft[key], !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            guard let number = parsedNumber(text), number.isFinite,
                  (!key.hasSuffix("Latitude") || (-90...90).contains(number)),
                  (!key.hasSuffix("Longitude") || (-180...180).contains(number)) else {
                invalidSiteNumber = true
                return
            }
        }
        // Capture only edited fields, including nil, so failure restores their exact values.
        var restore: [() -> Void] = []
        for (key, enteredValue) in draft {
            // Notes preserve their exact whitespace and line breaks.
            let newValue = key == "notes" ? enteredValue : enteredValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let path = Self.textFields[key] {
                let original = dive[keyPath: path]
                restore.append { dive[keyPath: path] = original }
                dive[keyPath: path] = newValue
            } else if let path = Self.optionalFields[key] {
                let original = dive[keyPath: path]
                restore.append { dive[keyPath: path] = original }
                dive[keyPath: path] = newValue.isEmpty ? nil : newValue
            } else if let path = Self.numericFields[key] {
                let original = dive[keyPath: path]
                restore.append { dive[keyPath: path] = original }
                dive[keyPath: path] = parsedNumber(newValue)
            }
        }
        do {
            try modelContext.save()
            draft = [:]
            saveError = nil
            store.commit(dive, affects: .rowFields)
        } catch {
            restore.forEach { $0() }
            saveError = error.localizedDescription
        }
    }
}
#endif
