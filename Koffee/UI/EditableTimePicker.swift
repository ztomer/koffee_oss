import SwiftUI

struct EditableTimePicker: View {
    @Binding var selection: Date
    let label: String

    @State private var textValue: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private let calendar = Calendar.current

    init(selection: Binding<Date>, label: String = "") {
        self._selection = selection
        self.label = label
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("HH:MM", text: $textValue)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 80)
                .multilineTextAlignment(.center)
                .focused($isFocused)
                .onChange(of: textValue) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber || $0 == ":" }
                    if filtered != newValue {
                        textValue = filtered
                        return
                    }

                    if newValue.count == 2 && !newValue.contains(":") {
                        let hour = Int(newValue) ?? 0
                        if hour > 23 {
                            textValue = String(newValue.prefix(1))
                            return
                        }
                        textValue = newValue + ":"
                        return
                    }

                    let components = textValue.split(separator: ":").compactMap { Int($0) }
                    if components.count == 2 {
                        let hour = min(max(components[0], 0), 23)
                        let minute = min(max(components[1], 0), 59)
                        var dateComponents = calendar.dateComponents([.year, .month, .day], from: selection)
                        dateComponents.hour = hour
                        dateComponents.minute = minute
                        if let newDate = calendar.date(from: dateComponents) {
                            selection = newDate
                            textValue = String(format: "%02d:%02d", hour, minute)
                        }
                    }
                }
                .onChange(of: isFocused) { _, newValue in
                    if !newValue {
                        textValue = timeFormatter.string(from: selection)
                    }
                }

            Stepper("", value: Binding(
                get: { calendar.component(.hour, from: selection) },
                set: { newHour in
                    let minutes = calendar.component(.minute, from: selection)
                    var components = calendar.dateComponents([.year, .month, .day], from: selection)
                    components.hour = newHour
                    components.minute = minutes
                    if let newDate = calendar.date(from: components) {
                        selection = newDate
                    }
                }
            ), in: 0...23)
            .labelsHidden()
            .controlSize(.small)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 8))
        .onAppear {
            textValue = timeFormatter.string(from: selection)
        }
    }

    private func parseAndUpdateTime() {
        let components = textValue.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else {
            textValue = timeFormatter.string(from: selection)
            return
        }

        let hour = min(max(components[0], 0), 23)
        let minute = min(max(components[1], 0), 59)

        var dateComponents = calendar.dateComponents([.year, .month, .day], from: selection)
        dateComponents.hour = hour
        dateComponents.minute = minute

        if let newDate = calendar.date(from: dateComponents) {
            selection = newDate
        }
        textValue = timeFormatter.string(from: selection)
    }
}

struct EditableTimePickerWithLabel: View {
    @Binding var selection: Date
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            EditableTimePicker(selection: $selection)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 20) {
        EditableTimePicker(selection: .constant(Date()))
        EditableTimePickerWithLabel(selection: .constant(Date()), label: "Wake Time")
        EditableTimePickerWithLabel(selection: .constant(Date()), label: "Sleep Time")
    }
    .padding()
}
