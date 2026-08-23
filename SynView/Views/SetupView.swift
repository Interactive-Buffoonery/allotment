import SwiftUI

struct SetupView: View {
    let store: UsageStore
    @State private var apiKey = ""
    @State private var errorMessage: String?
    @FocusState private var isKeyFocused: Bool
    @AccessibilityFocusState private var isErrorMessageFocused: Bool

    var body: some View {
        ZStack {
            DotBackground()
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 20)
                    Text("SYNVIEW ✿")
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.synPink)
                        .stickerBorder(shadow: .synInkShadow)
                        .rotationEffect(.degrees(-2))
                        .accessibilityLabel("SynView")
                        .accessibilityAddTraits(.isHeader)

                    VStack(spacing: 10) {
                        Text("See what's ready")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .accessibilityAddTraits(.isHeader)
                        Text("Track your Synthetic limits, refills, and history from your device.")
                            .foregroundStyle(Color.synMuted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("SYNTHETIC API KEY")
                            .font(.caption.bold())
                            .foregroundStyle(Color.synMuted)
                        SecureField("syn_…", text: $apiKey)
                            .accessibilityLabel("Synthetic API key")
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.password)
                            .focused($isKeyFocused)
                            .padding(16)
                            .background(Color.synPaper)
                            .notebookOutline(cornerRadius: 14)
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(Color.synError)
                                .accessibilityFocused($isErrorMessageFocused)
                        }
                    }

                    Button {
                        connect()
                    } label: {
                        Text("Connect Synthetic")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(.plain)
                    .background(Color.synYellow)
                    .stickerBorder()
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Text("Your key stays in this device's Keychain.")
                        .font(.footnote)
                        .foregroundStyle(Color.synMuted)
                    Spacer(minLength: 20)
                }
                .padding(24)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .task { isKeyFocused = true }
    }

    private func connect() {
        do {
            try store.saveAPIKey(apiKey)
            apiKey = ""
            Task { await store.refresh() }
        } catch {
            errorMessage = error.localizedDescription
            isErrorMessageFocused = true
        }
    }
}
