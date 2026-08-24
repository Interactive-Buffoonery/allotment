import SwiftUI

struct ProviderPickerView: View {
    let store: UsageStore
    var showsHero: Bool

    var body: some View {
        VStack(spacing: 24) {
            if showsHero {
                Spacer(minLength: 8)
                Text("ALLOTMENT ✿")
                    .font(.alloWordmark(size: 24))
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
                        providerRow(icon: provider.icon, name: provider.displayName, status: nil)
                    }
                    .buttonStyle(.plain)
                }
                providerRow(icon: "chevron.left.forwardslash.chevron.right", name: "Codex", status: "COMING SOON")
                providerRow(icon: "ellipsis", name: "More providers", status: "COMING SOON")
            }
            Spacer(minLength: 20)
        }
        .padding(24)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
    }

    private func providerRow(icon: String, name: String, status: String?) -> some View {
        HStack(spacing: 15) {
            Stamp(icon: icon, color: .alloMint, size: 46)
            Text(name)
                .font(.system(.title3, design: .rounded, weight: .bold))
            Spacer()
            if let status {
                ComingSoonChip()
            } else {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(Color.alloMuted)
                    .accessibilityHidden(true)
            }
        }
        .opacity(status == nil ? 1 : 0.55)
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
