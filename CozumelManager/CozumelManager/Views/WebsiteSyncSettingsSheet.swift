import SwiftUI

struct WebsiteSyncSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var siteURL: String
    @State private var username: String
    @State private var applicationPassword: String = ""
    private let store: WordPressSyncCredentialsStore

    init(store: WordPressSyncCredentialsStore = WordPressSyncCredentialsStore()) {
        self.store = store
        let existing = store.load()
        _siteURL = State(initialValue: existing?.siteURL ?? "http://cozumel-homes.local")
        _username = State(initialValue: existing?.username ?? "")
    }

    private var canSave: Bool {
        !siteURL.isEmpty && !username.isEmpty && !applicationPassword.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Website Sync Settings")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Generate an Application Password in wp-admin under Users → Profile, then paste it below.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Site URL", text: $siteURL)
                .textFieldStyle(.roundedBorder)
            TextField("WordPress Username", text: $username)
                .textFieldStyle(.roundedBorder)
            SecureField("Application Password", text: $applicationPassword)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    guard canSave else { return }
                    try? store.save(WordPressSyncCredentials(siteURL: siteURL, username: username, applicationPassword: applicationPassword))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
