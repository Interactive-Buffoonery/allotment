import SwiftUI

struct ProviderKeyView: View {
    let store: UsageStore
    let provider: Provider
    var onboarding: Bool

    @State private var apiKey = ""
    @State private var message: String?
    @State private var messageIsError = false
    @FocusState private var isKeyFocused: Bool
    @AccessibilityFocusState private var isMessageFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private var canSave: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.isLoading
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: onboarding ? 8 : 0)
            VStack(spacing: 10) {
                Stamp(icon: provider.icon, color: .alloMint, size: 54)
                Text(provider.displayName)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text("Connect your account")
                    .foregroundStyle(Color.alloMuted)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("\(provider.displayName.uppercased()) API KEY")
                    .font(.caption.bold())
                    .foregroundStyle(Color.alloMuted)
                SecureField(provider.keyPlaceholder, text: $apiKey)
                    .accessibilityLabel("\(provider.displayName) API key")
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.password)
                    .focused($isKeyFocused)
                    .disabled(store.isLoading)
                    .padding(16)
                    .background(Color.alloPaper)
                    .notebookOutline(cornerRadius: 14)
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(messageIsError ? Color.alloError : Color.alloMuted)
                        .accessibilityFocused($isMessageFocused)
                }
            }

            Button {
                saveKey()
            } label: {
                HStack(spacing: 10) {
                    if store.isLoading {
                        ProgressView()
                            .tint(Color.alloStickerInk)
                    }
                    Text(buttonTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.alloStickerInk)
            .background(Color.alloMauve)
            .stickerBorder()
            .disabled(!canSave)
            .accessibilityLabel(buttonTitle)

            Text("Your key stays in this device's Keychain.")
                .font(.footnote)
                .foregroundStyle(Color.alloMuted)
            Spacer(minLength: 20)
        }
        .padding(24)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("providers", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.alloRequestFill)
                }
                .accessibilityLabel("Back to providers")
                .disabled(store.isLoading)
            }
        }
        .task { if onboarding { isKeyFocused = true } }
    }

    private var buttonTitle: String {
        if store.isLoading { return "Checking Synthetic…" }
        return onboarding ? "Save provider" : "Update Key"
    }

    private func saveKey() {
        let submitted = apiKey
        Task {
            do {
                try await store.connect(submitted)
                apiKey = ""
                announce(onboarding ? "Connected to \(provider.displayName)." : "API key saved.")
                if onboarding { return }
                message = "API key saved."
                messageIsError = false
                isKeyFocused = false
                isMessageFocused = true
            } catch {
                message = error.localizedDescription
                messageIsError = true
                isMessageFocused = true
                announce(error.localizedDescription)
            }
        }
    }

    private func announce(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }
}
