import SwiftUI

struct MetabolicWidget: View {
    let interventions: [BiologicalIntervention]

    private var orange: Color { Color(red: 1.0, green: 0.596, blue: 0.0) }
    private var green: Color { Color(red: 0.298, green: 0.686, blue: 0.314) }
    private var red: Color { Color(red: 0.957, green: 0.263, blue: 0.208) }

    @State private var currentExercise: (name: String, isDebuff: Bool, maintainsPerfusion: Bool)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(orange)
                Text("METABOLIC")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let exercise = currentExercise {
                if exercise.isDebuff {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(red)
                            Text("Debuff")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(red)
                        }
                        Text("Clearance Paused")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(green)
                            Text("Buff")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(green)
                        }
                        Text("+15% Clearance")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(orange.opacity(0.6))
                        .frame(width: 6, height: 6)
                    Text("Baseline")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
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
                currentExercise = (
                    name: intervention.name,
                    isDebuff: !intervention.maintainsHepaticPerfusion,
                    maintainsPerfusion: intervention.maintainsHepaticPerfusion
                )
                return
            }
        }
        currentExercise = nil
    }
}
