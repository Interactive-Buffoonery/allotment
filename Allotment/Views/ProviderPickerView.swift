import SwiftUI

struct ProviderPickerView: View {
    let store: UsageStore
    var showsHero: Bool

    @State private var comingSoonName: String?

    var body: some View {
        VStack(spacing: 24) {
            if showsHero {
                Spacer(minLength: 8)
                Text("ALLOTMENT ✿")
                    .font(.alloWordmark(size: 24))
                    .foregroundStyle(Color.alloStickerInk)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.alloPink)
                    .stickerBorder(shadow: .alloInkShadow)
                    .rotationEffect(.degrees(-2))
                    .accessibilityLabel("Allotment")
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 10) {
                    Text("Connect a provider")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Track your AI limits, refills, and history from your iOS device.")
                        .foregroundStyle(Color.alloMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 14) {
                ForEach(Provider.allCases, id: \.self) { provider in
                    NavigationLink(value: provider) {
                        providerRow(
                            icon: provider.icon,
                            name: provider.displayName,
                            badge: store.hasAPIKey ? "CONNECTED" : nil
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(store.hasAPIKey ? "Opens key update" : "Connect this provider")
                }
                comingSoonRow(icon: "chevron.left.forwardslash.chevron.right", name: "Codex")
                comingSoonRow(icon: "ellipsis", name: "More providers")
            }
            Spacer(minLength: 20)
        }
        .padding(24)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
        .alert("Coming soon", isPresented: Binding(
            get: { comingSoonName != nil },
            set: { if !$0 { comingSoonName = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(comingSoonName ?? "") isn’t available yet.")
        }
    }

    private func comingSoonRow(icon: String, name: String) -> some View {
        Button {
            comingSoonName = name
        } label: {
            providerRow(icon: icon, name: name, badge: "COMING SOON", muted: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityValue("Coming soon")
        .accessibilityHint("Not available yet")
    }

    private func providerRow(icon: String, name: String, badge: String?, muted: Bool = false) -> some View {
        HStack(spacing: 15) {
            Stamp(icon: icon, color: .alloMint, size: 46)
            Text(name)
                .font(.system(.title3, design: .rounded, weight: .bold))
            Spacer()
            if let badge {
                ComingSoonChip(badge)
            } else {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(Color.alloMuted)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(muted ? Color.alloMuted : Color.alloInk)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.alloPaper)
        .stickerBorder(cornerRadius: 18, offset: 5)
    }
}

struct ComingSoonChip: View {
    init(_ text: String = "COMING SOON") { self.text = text }
    private let text: String

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .tracking(0.5)
            .foregroundStyle(Color.alloStickerInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.alloMauve)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.alloOutline, lineWidth: 1.5))
    }
}
