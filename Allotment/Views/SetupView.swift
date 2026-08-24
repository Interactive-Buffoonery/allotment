import SwiftUI

struct SetupView: View {
    let store: UsageStore

    var body: some View {
        NavigationStack {
            ZStack {
                DotBackground()
                ScrollView {
                    ProviderPickerView(store: store, showsHero: true)
                }
                .scrollDismissesKeyboard(.interactively)
                .navigationDestination(for: Provider.self) { provider in
                    ScrollView {
                        ProviderKeyView(store: store, provider: provider, onboarding: true)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .background(DotBackground())
                }
            }
        }
    }
}
