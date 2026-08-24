import SwiftUI

struct SettingsView: View {
    let store: UsageStore

    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue
    @State private var apiKey = ""
    @State private var keyMessage: String?
    @State private var keyMessageIsError = false
    @State private var showDisconnectConfirmation = false
    @FocusState private var isKeyFocused: Bool
    @AccessibilityFocusState private var isKeyMessageFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MAKE IT YOURS")
                    .font(.caption.bold())
                    .tracking(0.8)
                    .foregroundStyle(Color.alloMuted)
                Text("Settings")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .accessibilityAddTraits(.isHeader)
                Text("Keep the useful bits. Pick the fun bits.")
                    .font(.subheadline)
                    .foregroundStyle(Color.alloMuted)
            }

            appearanceCard
            apiKeyCard
        }
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Appearance")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Pick Allotment’s look on this device.")
                    .font(.subheadline)
                    .foregroundStyle(Color.alloMuted)
            }

            HStack(spacing: 4) {
                ForEach(AppAppearance.allCases, id: \.self) { option in
                    Button {
                        appearance = option.rawValue
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: option.icon)
                                .font(.headline)
                            Text(option.label)
                                .font(.system(.caption, design: .rounded, weight: .bold))
                        }
                        .foregroundStyle(Color.alloInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSelected(option) ? Color.alloPink : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityAddTraits(isSelected(option) ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Color.alloInk.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(19)
        .background(Color.alloPaper)
        .stickerBorder(cornerRadius: 22)
    }

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Synthetic API Key")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(store.hasAPIKey ? "A key is saved on this device." : "No key saved yet — add one to connect.")
                    .font(.subheadline)
                    .foregroundStyle(Color.alloMuted)
            }

            SecureField("syn_…", text: $apiKey)
                .accessibilityLabel("Synthetic API key")
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)
                .focused($isKeyFocused)
                .padding(16)
                .background(Color.alloInk.opacity(0.06))
                .notebookOutline(cornerRadius: 14)

            if let keyMessage {
                Text(keyMessage)
                    .font(.footnote)
                    .foregroundStyle(keyMessageIsError ? Color.alloError : Color.alloMuted)
                    .accessibilityFocused($isKeyMessageFocused)
            }

            Button {
                saveKey()
            } label: {
                Text(store.hasAPIKey ? "Update Key" : "Save Key")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.alloStickerInk)
            .background(Color.alloMauve)
            .stickerBorder()
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if store.hasAPIKey {
                Button("Disconnect Synthetic", role: .destructive) {
                    showDisconnectConfirmation = true
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, minHeight: 44)
            }

            Text("Your key stays in this device's Keychain.")
                .font(.footnote)
                .foregroundStyle(Color.alloMuted)
        }
        .padding(19)
        .background(Color.alloPaper)
        .stickerBorder(cornerRadius: 22)
        .confirmationDialog(
            "Disconnect Synthetic?",
            isPresented: $showDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                store.disconnect()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your saved history will remain on this device.")
        }
    }

    private func isSelected(_ option: AppAppearance) -> Bool {
        AppAppearance(rawValue: appearance) == option
    }

    private func saveKey() {
        do {
            try store.saveAPIKey(apiKey)
            apiKey = ""
            keyMessage = "API key saved."
            keyMessageIsError = false
            isKeyFocused = false
            isKeyMessageFocused = true
            Task { await store.refresh() }
        } catch {
            keyMessage = error.localizedDescription
            keyMessageIsError = true
            isKeyMessageFocused = true
        }
    }
}
