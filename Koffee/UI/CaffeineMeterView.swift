import SwiftUI

struct CaffeineMeterView: View {
    let level: Double
    let safeLimit: Double

    private var displayLevel: Double {
        min(level, safeLimit * 2)
    }

    private var statusText: String {
        if level <= safeLimit * 0.5 {
            return "Sleep well"
        } else if level <= safeLimit {
            return "Okay"
        } else {
            return "Too high"
        }
    }

    private var statusColor: Color {
        if level <= safeLimit * 0.5 {
            return .green
        } else if level <= safeLimit {
            return .yellow
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Gauge(value: displayLevel, in: 0...(safeLimit * 2)) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 10))
            } currentValueLabel: {
                Text("\(Int(level))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Gradient(colors: [.green, .yellow, .red]))
            .frame(width: 40, height: 40)

            Text(statusText)
                .font(.system(size: 6, weight: .medium))
                .foregroundStyle(statusColor)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    HStack(spacing: 20) {
        CaffeineMeterView(level: 25, safeLimit: 50)
        CaffeineMeterView(level: 40, safeLimit: 50)
        CaffeineMeterView(level: 80, safeLimit: 50)
    }
    .padding()
}
