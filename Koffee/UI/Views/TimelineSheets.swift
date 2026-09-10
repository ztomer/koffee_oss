import SwiftUI

struct SidebarActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(color.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct AddBeverageSheet: View {
    @ObservedObject var appState: AppState
    let onAdd: (BeverageModel, Date) -> Void
    let onDismiss: () -> Void
    @State private var selectedBeverageId: String?
    @State private var selectedTime = Date()

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Beverage").font(.headline).padding()
            List(appState.beverages, id: \.id) { beverage in
                Button {
                    selectedBeverageId = beverage.id
                } label: {
                    HStack {
                        Image(systemName: beverage.symbolName).font(.title2).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(beverage.name).font(.headline)
                                if beverage.id == appState.usualBeverageId {
                                    Text("USUAL")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.12))
                                        .clipShape(.capsule)
                                }
                            }
                            Text("\(beverage.caffeineMg)mg caffeine").font(.caption).foregroundStyle(.secondary)
                            consequenceLine(for: beverage)
                        }
                        Spacer()
                        if selectedBeverageId == beverage.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            DatePicker("Time", selection: $selectedTime).padding()

            HStack {
                Button("Cancel") { onDismiss() }.buttonStyle(.bordered)
                Spacer()
                Button("Add") {
                    if let id = selectedBeverageId, let beverage = appState.findBeverage(byId: id) {
                        onAdd(beverage, selectedTime)
                    }
                }.buttonStyle(.borderedProminent)
            }.padding()
        }
        .frame(width: 300, height: 400)
    }

    private func consequenceLine(for beverage: BeverageModel) -> some View {
        let projected = appState.projectedBedtimeCaffeine(byAdding: beverage, at: selectedTime)
        let limit = appState.safeCaffeineLimit
        let status: String
        let color: Color
        if projected <= limit * 0.5 {
            status = "Sleep ready"
            color = .green
        } else if projected <= limit {
            status = "Monitor"
            color = .yellow
        } else {
            status = "Over"
            color = .red
        }
        return Text("bedtime \(Int(projected))mg · \(status)")
            .font(.caption)
            .foregroundStyle(color)
    }
}
