import SwiftUI

struct StatPod: View {
    @Binding var value: String
    let label: String
    @Binding var isEditing: Bool
    let onSave: (String) -> Void

    @State private var editText: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 6) {
            if isEditing {
                TextField("", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(KoffeeColor.orange, lineWidth: 2)
                    )
                    .shadow(color: KoffeeColor.orange.opacity(0.3), radius: 4)
                    .onSubmit {
                        onSave(editText)
                        isEditing = false
                    }
                    .onAppear {
                        editText = value
                        focused = true
                    }
            } else {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(KoffeeColor.orange)
                    .onTapGesture {
                        editText = value
                        isEditing = true
                    }
            }

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

struct SkillPill: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? color : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1)
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
