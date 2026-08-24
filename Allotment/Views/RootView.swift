import SwiftUI

struct RootView: View {
    let store: UsageStore

    var body: some View {
        Group {
            if store.hasAPIKey {
                DashboardView(store: store)
            } else {
                SetupView(store: store)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.hasAPIKey)
    }
}

