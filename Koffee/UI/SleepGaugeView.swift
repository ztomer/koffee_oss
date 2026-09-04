import SwiftUI

struct SleepGaugeView: View {
    let score: Double?

    private var displayScore: Double {
        score ?? 0
    }

    private var scoreColor: Color {
        guard let score = score else { return .gray }
        if score >= 85 { return .green }
        if score >= 70 { return .yellow }
        return .red
    }

    private var statusText: String {
        guard let score = score else { return "--" }
        if score >= 85 { return "Great" }
        if score >= 70 { return "Good" }
        if score >= 50 { return "Fair" }
        return "Poor"
    }

    var body: some View {
        VStack(spacing: 4) {
            Gauge(value: displayScore, in: 0...100) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 10))
            } currentValueLabel: {
                Text("\(Int(displayScore))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(scoreColor)
            .frame(width: 40, height: 40)

            Text(statusText)
                .font(.system(size: 6, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(scoreColor.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        SleepGaugeView(score: 92)
        SleepGaugeView(score: 75)
        SleepGaugeView(score: 45)
        SleepGaugeView(score: nil)
    }
    .padding()
}
