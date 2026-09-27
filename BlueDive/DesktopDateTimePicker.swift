#if os(macOS)
import SwiftUI
import AppKit

/// AppKit supports editing seconds on Mac. Merely displaying a timestamp must
/// not round it or write it back through the binding.
struct DesktopDateTimePicker: NSViewRepresentable {
    @Binding var selection: Date
    @Environment(\.locale) private var locale

    func makeNSView(context: Context) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.yearMonthDay, .hourMinuteSecond]
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.changed(_:))
        return picker
    }

    func updateNSView(_ picker: NSDatePicker, context: Context) {
        context.coordinator.selection = $selection
        picker.locale = locale
        if picker.dateValue != selection { picker.dateValue = selection }
    }

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

    final class Coordinator: NSObject {
        var selection: Binding<Date>

        init(selection: Binding<Date>) { self.selection = selection }

        @objc func changed(_ picker: NSDatePicker) {
            selection.wrappedValue = picker.dateValue
        }
    }
}
#endif
