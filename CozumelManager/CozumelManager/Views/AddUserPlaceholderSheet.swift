import SwiftUI

struct AddUserPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Add User")
                .font(.title2)
                .fontWeight(.semibold)
            Text("User management is coming soon.")
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(40)
        .frame(width: 320)
    }
}
