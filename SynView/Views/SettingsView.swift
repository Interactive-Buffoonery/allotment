import SwiftUI

struct SettingsView: View {
    let store: UsageStore

    @AppStorage(UsageLayout.storageKey) private var usageLayout = UsageLayout.bars.rawValue
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
                    .foregroundStyle(Color.synMuted)
                Text("Settings")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .accessibilityAddTraits(.isHeader)
                Text("Keep the useful bits. Pick the fun bits.")
                    .font(.subheadline)
                    .foregroundStyle(Color.synMuted)
            }

            layoutCard
            appearanceCard
            apiKeyCard
        }
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var layoutCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("PICK YOUR VIEW ✦")
                .font(.system(.headline, design: .rounded, weight: .black))
                .tracking(0.6)
                .padding(.horizontal, 17)
                .padding(.vertical, 11)
                .background(Color.synPink)
                .stickerBorder(cornerRadius: 10, offset: 5)
                .rotationEffect(.degrees(-1.4))
                .accessibilityLabel("Pick your view")
                .accessibilityAddTraits(.isHeader)

            layoutButton(.bars, color: .synYellow, rotation: -1.2)

            Text("OR")
                .font(.system(.caption, design: .rounded, weight: .black))
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(Color.synPaper)
                .notebookOutline(cornerRadius: 18)
                .frame(maxWidth: .infinity)
                .rotationEffect(.degrees(2))

            layoutButton(.rings, color: .synBlue, rotation: 1.1)
        }
    }

    private func layoutButton(_ option: UsageLayout, color: Color, rotation: Double) -> some View {
        Button {
            usageLayout = option.rawValue
        } label: {
            HStack(spacing: 17) {
                layoutPreview(option)

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.label)
                        .font(.system(.title2, design: .rounded, weight: .black))
                    Text(option == .bars ? "A playful gate ledger" : "Two quotas at a glance")
                        .font(.subheadline.bold())
                        .opacity(0.72)
                }

                Spacer()

                if isSelected(option) {
                    Image(systemName: "checkmark")
                        .font(.headline.bold())
                        .foregroundStyle(Color.synPaper)
                        .frame(width: 38, height: 38)
                        .background(Color.synInk)
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(option == .bars ? Color.synPlannerInk : Color.synInk)
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .background(color)
            .stickerBorder(cornerRadius: 19, offset: 7)
            .rotationEffect(.degrees(rotation))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected(option) ? .isSelected : [])
        .accessibilityHint("Uses the \(option.label.lowercased()) quota layout on the Current tab")
    }

    @ViewBuilder
    private func layoutPreview(_ option: UsageLayout) -> some View {
        if option == .bars {
            VStack(spacing: 7) {
                miniBar(width: 50)
                miniBar(width: 70)
            }
            .frame(width: 76, height: 54)
        } else {
            HStack(spacing: 7) {
                miniRing(progress: 0.42)
                miniRing(progress: 0.82)
            }
            .frame(width: 76, height: 54)
        }
    }

    private func miniBar(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.48))
                .frame(width: 70, height: 12)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.synPurple)
                .frame(width: width, height: 12)
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.synOutline, lineWidth: 2))
    }

    private func miniRing(progress: Double) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.48), lineWidth: 7)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.synPurple, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 31, height: 31)
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
                .accessibilityLabel("Synthetic API key")
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
            .foregroundStyle(Color.synPlannerInk)
            .background(Color.synYellow)
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
                .foregroundStyle(Color.synMuted)
        }
        .padding(19)
        .background(Color.synPaper)
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

    private func isSelected(_ option: UsageLayout) -> Bool {
        UsageLayout(rawValue: usageLayout) == option
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
