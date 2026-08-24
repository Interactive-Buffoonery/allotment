import SwiftUI

struct SettingsView: View {
    let store: UsageStore

    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue
    @State private var showDisconnectConfirmation = false

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

            providersSection
            appearanceCard
            iCloudSection
        }
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var providersSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Providers")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Keys live in this device's Keychain.")
                    .font(.subheadline)
                    .foregroundStyle(Color.alloMuted)
            }

            ForEach(Provider.allCases, id: \.self) { provider in
                if store.hasAPIKey {
                    NavigationLink {
                        ZStack {
                            DotBackground()
                            ScrollView {
                                ProviderKeyView(store: store, provider: provider, onboarding: false)
                            }
                        }
                    } label: {
                        providerRow(provider)
                    }
                    .buttonStyle(.plain)
                } else {
                    providerRow(provider)
                }
            }

            NavigationLink {
                ZStack {
                    DotBackground()
                    ScrollView {
                        ProviderPickerView(store: store, showsHero: false)
                    }
                }
                .navigationDestination(for: Provider.self) { provider in
                    ZStack {
                        DotBackground()
                        ScrollView {
                            ProviderKeyView(store: store, provider: provider, onboarding: false)
                        }
                    }
                }
            } label: {
                HStack(spacing: 15) {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 39, height: 39)
                        .overlay(Circle().strokeBorder(Color.alloMuted, style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
                    Text("Add provider")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Spacer()
                }
                .foregroundStyle(Color.alloMuted)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.alloMuted.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
            }
            .buttonStyle(.plain)

            if store.hasAPIKey {
                Button("Disconnect Synthetic", role: .destructive) {
                    showDisconnectConfirmation = true
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, minHeight: 44)
            }
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

    private func providerRow(_ provider: Provider) -> some View {
        HStack(spacing: 15) {
            Stamp(icon: provider.icon, color: .alloMint, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(provider.displayName)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Text(store.hasAPIKey ? "Key on this device" : "No key saved yet")
                    .font(.subheadline)
                    .foregroundStyle(Color.alloMuted)
            }
            Spacer()
            if store.hasAPIKey {
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.alloMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.alloInk.opacity(0.05))
        .notebookOutline(cornerRadius: 14)
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

    private var iCloudSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("iCloud Sync")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                ComingSoonChip()
            }
            Text("Sync providers, keys, and history across your devices.")
                .font(.subheadline)
                .foregroundStyle(Color.alloMuted)
        }
        .opacity(0.55)
        .padding(19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.alloPaper)
        .stickerBorder(cornerRadius: 22)
        .accessibilityElement(children: .combine)
    }

    private func isSelected(_ option: AppAppearance) -> Bool {
        AppAppearance(rawValue: appearance) == option
    }
}
