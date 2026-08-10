import SwiftUI

struct SettingsView: View {
    let store: UsageStore

    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue
    @State private var apiKey = ""
    @State private var keyMessage: String?
    @State private var keyMessageIsError = false
    @FocusState private var isKeyFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            appearanceCard
            apiKeyCard
        }
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Appearance")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Pick SynView’s look on this device.")
                    .font(.subheadline)
                    .foregroundStyle(Color.synMuted)
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
                        .foregroundStyle(Color.synInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSelected(option) ? Color.synPink : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityAddTraits(isSelected(option) ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Color.synInk.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(19)
        .background(Color.synPaper)
        .stickerBorder(cornerRadius: 22)
    }

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Synthetic API Key")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(store.hasAPIKey ? "A key is saved on this device." : "No key saved yet — add one to connect.")
                    .font(.subheadline)
                    .foregroundStyle(Color.synMuted)
            }

            SecureField("syn_…", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)
                .focused($isKeyFocused)
                .padding(16)
                .background(Color.synInk.opacity(0.06))
                .notebookOutline(cornerRadius: 14)

            if let keyMessage {
                Text(keyMessage)
                    .font(.footnote)
                    .foregroundStyle(keyMessageIsError ? Color.synError : Color.synMuted)
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
            .background(Color.synYellow)
            .stickerBorder()
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Text("Your key stays in this device’s Keychain.")
                .font(.footnote)
                .foregroundStyle(Color.synMuted)
        }
        .padding(19)
        .background(Color.synPaper)
        .stickerBorder(cornerRadius: 22)
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
            Task { await store.refresh() }
        } catch {
            keyMessage = error.localizedDescription
            keyMessageIsError = true
        }
    }
}
