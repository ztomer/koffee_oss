import SwiftUI

struct KoffeeTimeStepper: View {
    @Binding var time: Date
    @FocusState private var isFocused: Bool

    private let calendar = Calendar.current

    private var hours: Int {
        calendar.component(.hour, from: time)
    }

    private var minutes: Int {
        calendar.component(.minute, from: time)
    }

    private func updateTime(hours: Int? = nil, minutes: Int? = nil) {
        var components = calendar.dateComponents([.year, .month, .day], from: time)
        if let h = hours {
            components.hour = h
        }
        if let m = minutes {
            components.minute = m
        }
        if let newDate = calendar.date(from: components) {
            time = newDate
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 2) {
                Button {
                    updateTime(hours: (hours + 1) % 24)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isFocused ? KoffeeColor.orange : .secondary)
                }
                .buttonStyle(.plain)

                Text(String(format: "%02d", hours))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(isFocused ? KoffeeColor.orange : .primary)
                    .frame(minWidth: 36)

                Button {
                    updateTime(hours: (hours - 1 + 24) % 24)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isFocused ? KoffeeColor.orange : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? KoffeeColor.orange : Color.clear, lineWidth: 2)
            )
            .shadow(color: isFocused ? KoffeeColor.orange.opacity(0.3) : .clear, radius: 4)

            Text(":")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)

            HStack(spacing: 2) {
                Button {
                    updateTime(minutes: (minutes + 5) % 60)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isFocused ? KoffeeColor.orange : .secondary)
                }
                .buttonStyle(.plain)

                Text(String(format: "%02d", minutes))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(isFocused ? KoffeeColor.orange : .primary)
                    .frame(minWidth: 36)

                Button {
                    updateTime(minutes: (minutes - 5 + 60) % 60)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isFocused ? KoffeeColor.orange : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? KoffeeColor.orange : Color.clear, lineWidth: 2)
            )
            .shadow(color: isFocused ? KoffeeColor.orange.opacity(0.3) : .clear, radius: 4)
        }
        .focused($isFocused)
        .onTapGesture {
            isFocused = true
        }
    }
}

#Preview {
    @Previewable @State var time = DateHelper.now
    return KoffeeTimeStepper(time: $time)
        .padding()
}
