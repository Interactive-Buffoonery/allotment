import Charts
import SwiftUI

struct DashboardView: View {
    private enum AppTab: Hashable {
        case current
        case history
        case settings
    }

    let store: UsageStore
    @State private var selectedTab = AppTab.current
    @State private var showsDisconnectConfirmation = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                page {
                    CurrentUsageContent(store: store)
                }
                .refreshable { await store.refresh() }
                .navigationTitle("SynView")
                .toolbar { optionsMenu }
            }
            .tabItem {
                Label("Current", systemImage: "gauge")
            }
            .tag(AppTab.current)

            NavigationStack {
                page {
                    UsageHistoryView(history: store.history)
                }
                .navigationTitle("History")
            }
            .tabItem {
                Label("History", systemImage: "chart.bar.fill")
            }
            .tag(AppTab.history)

            NavigationStack {
                page {
                    SettingsView(store: store)
                }
                .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(AppTab.settings)
        }
        .tint(.synPurple)
        .task {
            if store.snapshot == nil { await store.refresh() }
        }
        .confirmationDialog("Disconnect Synthetic?", isPresented: $showsDisconnectConfirmation) {
            Button("Disconnect", role: .destructive) { store.disconnect() }
        } message: {
            Text("SynView will remove the API key from this device. Your saved history will remain.")
        }
    }

    private func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            DotBackground()
            ScrollView {
                content()
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
            }
        }
        .foregroundStyle(Color.synInk)
    }

    @ToolbarContentBuilder
    private var optionsMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await store.refresh() }
                }
                Button("Disconnect", systemImage: "key.slash", role: .destructive) {
                    showsDisconnectConfirmation = true
                }
            } label: {
                Image(systemName: store.isLoading ? "ellipsis.circle" : "ellipsis.circle.fill")
            }
            .accessibilityLabel("SynView options")
        }
    }
}

private struct CurrentUsageContent: View {
    let store: UsageStore

    @ViewBuilder
    var body: some View {
        if let snapshot = store.snapshot {
            CurrentUsageView(snapshot: snapshot, lastUpdated: store.lastUpdated)
        } else if store.isLoading {
            ProgressView("Checking Synthetic…")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.synInk)
                .tint(.synInk)
                .padding(.top, 80)
        } else {
            EmptyUsageView(message: store.errorMessage ?? "No quota data is available yet.") {
                Task { await store.refresh() }
            }
        }
    }
}

private struct CurrentUsageView: View {
    let snapshot: QuotaResponse
    let lastUpdated: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("TODAY’S CHECK-IN ✿")
                .font(.system(.headline, design: .rounded, weight: .black))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.synPink)
                .stickerBorder(cornerRadius: 10)
                .rotationEffect(.degrees(-1))

            if let rolling = snapshot.rollingFiveHourLimit {
                RollingLedgerCard(limit: rolling, lastUpdated: lastUpdated)
            } else if let subscription = snapshot.subscription {
                LegacyLedgerCard(quota: subscription, lastUpdated: lastUpdated)
            }

            if let weekly = snapshot.weeklyTokenLimit {
                WeeklyPlannerCard(limit: weekly)
            }
        }
    }
}

private struct RollingLedgerCard: View {
    let limit: RollingFiveHourLimit
    let lastUpdated: Date?

    private var ratio: Double { limit.max > 0 ? limit.remaining / limit.max : 0 }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 15) {
                Text("FIVE-HOUR REQUESTS AVAILABLE")
                    .font(.caption.bold())
                    .foregroundStyle(Color.synMuted)
                Text("\(limit.remaining.formatted(.number.precision(.fractionLength(0...1)))) ") +
                    Text("/ \(limit.max.formatted(.number.precision(.fractionLength(0))))")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(Color.synMuted)
            }
            .font(.system(size: 42, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(21)

            HStack(spacing: 5) {
                ForEach(0..<10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Double(index) < ratio * 10 ? blockColor(index) : Color.synInk.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.synOutline, lineWidth: 1))
                        .frame(height: 17)
                }
            }
            .padding(.horizontal, 21)
            .padding(.bottom, 18)

            DashedDivider()
            LedgerRow(icon: "arrow.up.right", color: .synMint, label: "USED CAPACITY", value: format(limit.max - limit.remaining), trailing: percent(1 - ratio))
            Divider().padding(.leading, 72)
            TimelineView(.periodic(from: .now, by: 60)) { context in
                LedgerRow(icon: "clock", color: .synBlue, label: "NEXT FIVE-HOUR REFILL", value: "+\(format(limit.refillAmount)) in \(countdown(to: limit.nextTickDate, now: context.date))", trailing: "EVERY 15M")
            }
            Divider().padding(.leading, 72)
            LedgerRow(icon: "checkmark", color: .synPink, label: "LAST CHECKED", value: lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "Just now", trailing: limit.limited ? "LIMITED" : "LIVE")
        }
        .background(Color.synPaper)
        .stickerBorder(cornerRadius: 22)
    }

    private func blockColor(_ index: Int) -> Color { index < 5 ? .synMint : .synYellow }
}

private struct LegacyLedgerCard: View {
    let quota: RequestQuota
    let lastUpdated: Date?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text("REQUESTS AVAILABLE")
                    .font(.caption.bold())
                    .foregroundStyle(Color.synMuted)
                Text("\(format(max(0, quota.limit - quota.requests))) / \(format(quota.limit))")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(21)
            DashedDivider()
            LedgerRow(icon: "arrow.up.right", color: .synMint, label: "USED CAPACITY", value: format(quota.requests), trailing: percent(quota.requests / max(1, quota.limit)))
            Divider().padding(.leading, 72)
            LedgerRow(icon: "checkmark", color: .synPink, label: "LAST CHECKED", value: lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "Just now", trailing: "LIVE")
        }
        .background(Color.synPaper)
        .stickerBorder(cornerRadius: 22)
    }
}

private struct WeeklyPlannerCard: View {
    let limit: WeeklyTokenLimit
    @State private var target: Double

    init(limit: WeeklyTokenLimit) {
        self.limit = limit
        _target = State(initialValue: min(limit.maximum, limit.remaining + limit.refillAmount * 8))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 15) {
                Text("WEEKLY REFILL PLANNER ✦")
                    .font(.caption.bold())
                    .tracking(0.5)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("AVAILABLE NOW")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.synMuted)
                        Text(limit.remaining, format: .currency(code: "USD"))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text("of \(limit.maximum.formatted(.currency(code: "USD")))")
                            .font(.caption.bold())
                            .foregroundStyle(Color.synMuted)
                    }
                    Spacer()
                    Text(percent(limit.percentRemaining / 100))
                        .font(.caption.bold())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.synMint)
                        .notebookOutline(cornerRadius: 8)
                }

                HStack(spacing: 9) {
                    RefillFact(label: "NEXT REFILL", value: "+\(limit.refillAmount.formatted(.currency(code: "USD"))) in \(countdown(to: limit.nextRefillDate, now: context.date))")
                    RefillFact(label: "REFILL SPEED", value: "+\(limit.refillAmount.formatted(.currency(code: "USD"))) every 3h 22m")
                }

                DashedDivider(color: Color.synInk.opacity(0.35))

                if limit.remaining < limit.maximum, limit.refillAmount > 0 {
                    HStack {
                        Text("I want available")
                            .font(.subheadline.bold())
                        Spacer()
                        Text(target, format: .currency(code: "USD"))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                    }
                    Slider(value: $target, in: limit.remaining...limit.maximum, step: limit.refillAmount)
                        .tint(.synPurple)
                        .accessibilityLabel("Target weekly credits")

                    HStack(spacing: 12) {
                        Stamp(icon: "clock", color: .synPurple.opacity(0.25))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("IF YOU PAUSE NEW USAGE")
                                .font(.caption2.bold())
                                .foregroundStyle(Color.synMuted)
                            Text("You’ll reach that in about \(duration(limit.timeToReach(target, now: context.date))).")
                                .font(.subheadline.bold())
                        }
                    }
                } else {
                    Label("Your weekly credits are fully regenerated.", systemImage: "sparkles")
                        .font(.subheadline.bold())
                }
            }
            .padding(18)
            .background(Color.synYellow)
            .stickerBorder(cornerRadius: 18)
        }
        .onChange(of: limit.remaining) { _, newValue in
            target = min(limit.maximum, max(newValue, target))
        }
    }
}

private struct UsageHistoryView: View {
    let history: [DailySnapshot]
    @State private var days = 7

    private var visibleHistory: [DailySnapshot] { Array(history.suffix(days)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your Usage")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Weekly credits available by day")
                        .font(.subheadline)
                        .foregroundStyle(Color.synMuted)
                }
                Spacer()
                HStack(spacing: 3) {
                    rangeButton(7)
                    rangeButton(30)
                }
                .padding(3)
                .background(Color.synPaper)
                .notebookOutline(cornerRadius: 11)
            }

            if visibleHistory.isEmpty {
                EmptyHistoryView()
            } else {
                historyChart
                activitySummary
            }

            Text("History begins after SynView’s first check-in and stays on this device.")
                .font(.footnote)
                .foregroundStyle(Color.synMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    private var historyChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AVAILABLE CREDITS")
                .font(.caption.bold())
                .foregroundStyle(Color.synMuted)
            Chart(visibleHistory) { item in
                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Credits", item.weeklyRemaining)
                )
                .foregroundStyle(Color.synMint.gradient)
                .cornerRadius(6)
                .annotation(position: .top) {
                    Text(item.weeklyRemaining, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.caption2.bold())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 190)
        }
        .padding(19)
        .background(Color.synPaper)
        .stickerBorder(cornerRadius: 22)
    }

    private var activitySummary: some View {
        HStack(spacing: 13) {
            SummaryCard(label: "LEAST ACTIVE DAY", value: dayName(visibleHistory.max { $0.weeklyRemaining < $1.weeklyRemaining }?.date), color: .synMint)
            SummaryCard(label: "MOST ACTIVE DAY", value: dayName(visibleHistory.min { $0.weeklyRemaining < $1.weeklyRemaining }?.date), color: .synPink)
        }
    }

    private func rangeButton(_ value: Int) -> some View {
        Button(value == 7 ? "7D" : "30D") { days = value }
            .font(.caption.bold())
            .foregroundStyle(Color.synInk)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(days == value ? Color.synPurple.opacity(0.3) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .accessibilityAddTraits(days == value ? .isSelected : [])
    }

    private func dayName(_ date: Date?) -> String {
        date?.formatted(.dateTime.weekday(.wide)) ?? "—"
    }
}

private struct LedgerRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String
    let trailing: String

    var body: some View {
        HStack(spacing: 12) {
            Stamp(icon: icon, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(Color.synMuted)
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            }
            Spacer()
            Text(trailing)
                .font(.caption2.bold())
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }
}

private struct Stamp: View {
    let icon: String
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.subheadline.bold())
            .frame(width: 39, height: 39)
            .background(color)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.synOutline, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

private struct RefillFact: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(Color.synMuted)
            Text(value)
                .font(.caption.bold())
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.synPaper.opacity(0.65))
        .notebookOutline(cornerRadius: 11)
    }
}

private struct SummaryCard: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(Color.synMuted)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(15)
        .background(color)
        .stickerBorder(cornerRadius: 17)
    }
}

private struct DashedDivider: View {
    var color = Color.synMuted.opacity(0.4)

    var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            .foregroundStyle(color)
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

private struct EmptyUsageView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud.sun")
                .font(.largeTitle)
            Text(message)
                .multilineTextAlignment(.center)
            Button("Try Again", action: retry)
                .font(.headline)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color.synYellow)
        .stickerBorder(cornerRadius: 18)
    }
}

private struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
            Text("Your first data point is ready")
                .font(.system(.headline, design: .rounded, weight: .bold))
            Text("Check back tomorrow to start seeing a trend.")
                .font(.subheadline)
                .foregroundStyle(Color.synMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.synPaper)
        .stickerBorder(cornerRadius: 20)
    }
}

private func format(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(value.rounded() == value ? 0 : 1)))
}

private func percent(_ ratio: Double) -> String {
    ratio.formatted(.percent.precision(.fractionLength(0)))
}

private func countdown(to date: Date?, now: Date) -> String {
    guard let date else { return "soon" }
    return duration(max(0, date.timeIntervalSince(now)))
}

private func duration(_ interval: TimeInterval) -> String {
    let minutes = max(0, Int(interval / 60))
    let days = minutes / 1440
    let hours = minutes % 1440 / 60
    let remainingMinutes = minutes % 60
    return [days > 0 ? "\(days)d" : nil, hours > 0 ? "\(hours)h" : nil, remainingMinutes > 0 ? "\(remainingMinutes)m" : nil]
        .compactMap { $0 }
        .joined(separator: " ")
        .nonEmpty ?? "now"
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
