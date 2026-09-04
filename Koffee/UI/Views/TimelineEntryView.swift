import SwiftUI

struct TimelineEntryView: View {
    let entry: ProtocolTimelineEntry
    let isCompleted: Bool
    let isSkipped: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onApprove: () -> Void
    let onSkip: () -> Void
    let onDisapprove: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.scheduledTime, format: .dateTime.hour().minute())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .frame(width: 50, alignment: .trailing)
                .foregroundColor(entry.isSuggestion ? .orange : .primary)

            ZStack {
                Circle().fill(iconColor).frame(width: 36, height: 36)
                Image(systemName: entry.icon).font(.system(size: 16)).foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).font(.system(size: 12, weight: .medium)).foregroundColor(titleColor).lineLimit(2)
                Text(entry.subtitle).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if entry.isSuggestion {
                Button(action: onApprove) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundColor(.green.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundColor(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .onTapGesture(perform: onTap)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
        }
    }

    private var iconColor: Color {
        if isCompleted { return .green }
        if isSkipped { return .gray }
        if entry.type == .supplement {
            return colorForCompound(entry.title)
        }
        switch entry.type {
        case .beverage: return .orange
        case .physical: return .blue
        case .hydration: return .cyan
        case .supplement: return .purple
        }
    }

    private var titleColor: Color {
        if isCompleted { return .green }
        if isSkipped { return .gray }
        return .primary
    }

    private var backgroundColor: Color {
        if isCompleted { return Color.green.opacity(0.5) }
        if isSkipped { return Color.gray.opacity(0.4) }
        if isSelected { return Color.orange.opacity(0.3) }
        return Color.clear
    }
}
