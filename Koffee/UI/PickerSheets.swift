import SwiftUI

struct BeveragePickerSheet: View {
    let beverages: [BeverageModel]
    let onSelect: (BeverageModel) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Beverage")
                .font(.headline)
                .padding()

            List(beverages) { beverage in
                Button {
                    onSelect(beverage)
                } label: {
                    HStack {
                        Text(beverage.icon)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text(beverage.name)
                                .font(.headline)
                            Text("\(beverage.caffeineMg)mg caffeine")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }

            Button("Cancel") {
                onDismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 400)
    }
}

struct SupplementPickerSheet: View {
    let availableCompounds: [NootropicCompound]
    let onSelect: (NootropicCompound) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Supplement")
                .font(.headline)
                .padding()

            List(availableCompounds, id: \.rawValue) { compound in
                Button {
                    onSelect(compound)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(compound.rawValue)
                                .font(.headline)
                            Text(compound.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text("\(Int(compound.optimalDoseMg))mg")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }

            Button("Cancel") {
                onDismiss()
            }
            .padding()
        }
        .frame(width: 350, height: 400)
    }
}

struct ActivityOption: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
}

let availableActivities = [
    ActivityOption(name: "Running", icon: "figure.run", description: "Cardio exercise"),
    ActivityOption(name: "Walking", icon: "figure.walk", description: "Light exercise"),
    ActivityOption(name: "Cycling", icon: "figure.outdoor.cycle", description: "Cardio exercise"),
    ActivityOption(name: "Strength Training", icon: "figure.strengthtraining.traditional", description: "Weight training"),
    ActivityOption(name: "Yoga", icon: "figure.yoga", description: "Flexibility and mindfulness"),
    ActivityOption(name: "Swimming", icon: "figure.pool.swim", description: "Full body cardio")
]

struct ActivityPickerSheet: View {
    let onSelect: (ActivityOption) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Physical Activity")
                .font(.headline)
                .padding()

            List(availableActivities) { activity in
                Button {
                    onSelect(activity)
                } label: {
                    HStack {
                        Image(systemName: activity.icon)
                            .font(.title2)
                            .frame(width: 40)
                        VStack(alignment: .leading) {
                            Text(activity.name)
                                .font(.headline)
                            Text(activity.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }

            Button("Cancel") {
                onDismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 350)
    }
}
