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
                        Text(beverage.icon).font(.title2)
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

struct AddSupplementSheet: View {
    @ObservedObject var appState: AppState
    let onAdd: (String) -> Void
    let onDismiss: () -> Void
    @State private var selectedCompound: String = NootropicCompound.caffeine.rawValue

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Supplement").font(.headline).padding()

            List {
                ForEach(NootropicCompound.allCases.filter { $0 != .custom }, id: \.rawValue) { compound in
                    Button(action: {
                        onAdd(compound.rawValue)
                    }, label: {
                        HStack {
                            Text(compound.rawValue)
                            Spacer()
                            Text("\(Int(compound.optimalDoseMg))mg")
                                .foregroundStyle(.secondary)
                        }
                    })
                }
            }

            Button("Cancel") { onDismiss() }.buttonStyle(.bordered)
        }
        .frame(width: 300, height: 350)
    }
}

struct AddExerciseSheet: View {
    @ObservedObject var appState: AppState
    let onAdd: (String, Int?) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Log Exercise").font(.headline).padding()

            List {
                Button("Walking") { onAdd("Walking", 30) }
                Button("Running") { onAdd("Running", 30) }
                Button("Cycling") { onAdd("Cycling", 45) }
                Button("Yoga") { onAdd("Yoga", 30) }
                Button("Weights") { onAdd("Weights", 45) }
                Button("Swimming") { onAdd("Swimming", 30) }
                Button("HIIT") { onAdd("HIIT", 20) }
            }

            Button("Cancel") { onDismiss() }.buttonStyle(.bordered)
        }
        .frame(width: 300, height: 350)
    }
}
