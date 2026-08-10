import SwiftUI

struct SetupView: View {
    let store: UsageStore
    @State private var apiKey = ""
    @State private var errorMessage: String?
    @FocusState private var isKeyFocused: Bool

    var body: some View {
        ZStack {
            DotBackground()
            VStack(spacing: 28) {
                Spacer()
                Text("SYNVIEW ✿")
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.synPink)
                    .stickerBorder()
                    .rotationEffect(.degrees(-1))

                VStack(spacing: 10) {
                    Text("See what’s ready")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Track your Synthetic limits, refills, and history from your phone.")
                        .foregroundStyle(Color.synMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("SYNTHETIC API KEY")
                        .font(.caption.bold())
                        .foregroundStyle(Color.synMuted)
                    SecureField("syn_…", text: $apiKey)
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

                Text("Your key stays in this device’s Keychain.")
                    .font(.footnote)
                    .foregroundStyle(Color.synMuted)
                Spacer()
            }
            .padding(24)
        }
        .onAppear { isKeyFocused = true }
    }

    private func connect() {
        do {
            try store.saveAPIKey(apiKey)
            Task { await store.refresh() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
