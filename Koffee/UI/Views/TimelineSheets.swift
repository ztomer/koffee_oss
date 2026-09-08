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
                        VStack(alignment: .leading) {
                            Text(beverage.name).font(.headline)
                            Text("\(beverage.caffeineMg)mg caffeine").font(.caption).foregroundStyle(.secondary)
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
}
