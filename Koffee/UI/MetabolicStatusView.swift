import SwiftUI

struct MetabolicStatusView: View {
    let interventions: [BiologicalIntervention]
    @State private var currentExercise: (name: String, isDebuff: Bool, maintainsPerfusion: Bool)?

    private let orange = Color(red: 1.0, green: 0.596, blue: 0.0)
    private let green = Color(red: 0.298, green: 0.686, blue: 0.314)
    private let red = Color(red: 0.957, green: 0.263, blue: 0.208)

    var body: some View {
        HStack(spacing: 8) {
            if let exercise = currentExercise {
                // Debuff or Buff display
                if exercise.isDebuff {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(red)

                        Text("Debuff: Hepatic Shunting")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(red)

                        Text("(Clearance Paused)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(red.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(red.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(green)

                        Text("Buff: Elevated Perfusion")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(green)

                        Text("(+15% Clearance)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(green.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(green.opacity(0.3), lineWidth: 1)
                    )
                }
            } else {
                // No active exercise - neutral state
                HStack(spacing: 6) {
                    Circle()
                        .fill(orange.opacity(0.6))
                        .frame(width: 6, height: 6)

                    Text("Baseline Metabolism")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { checkActiveExercise() }
        .onChange(of: interventions) { _, _ in checkActiveExercise() }
    }

    private func checkActiveExercise() {
        let now = Date()

        for intervention in interventions where intervention.type == .exercise {
            let start = intervention.scheduledTime
            let duration = intervention.durationMinutes ?? 30
            let end = start.addingTimeInterval(Double(duration) * 60)

            if now >= start && now < end {
                // Found active exercise
                currentExercise = (
                    name: intervention.name,
                    isDebuff: !intervention.maintainsHepaticPerfusion,
                    maintainsPerfusion: intervention.maintainsHepaticPerfusion
                )
                return
            }
        }

        // No active exercise
        currentExercise = nil
    }
}

#Preview {
    VStack(spacing: 20) {
        // No exercise
        MetabolicStatusView(interventions: [])

        // HIIT (debuff)
        MetabolicStatusView(interventions: [
            BiologicalIntervention(
                id: "1",
                name: "HIIT",
                scheduledTime: Date().addingTimeInterval(-1800),
                type: .exercise,
                durationMinutes: 30,
                maintainsHepaticPerfusion: false
            )
        ])

        // Zone 2 (buff)
        MetabolicStatusView(interventions: [
            BiologicalIntervention(
                id: "2",
                name: "Zone 2 Cardio",
                scheduledTime: Date().addingTimeInterval(-1800),
                type: .exercise,
                durationMinutes: 30,
                maintainsHepaticPerfusion: true
            )
        ])
    }
    .padding()
}
