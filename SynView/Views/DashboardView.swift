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

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                page {
                    VStack(alignment: .leading, spacing: 24) {
                        CurrentHeader(store: store)
                        CurrentUsageContent(store: store)
                    }
                }
                .refreshable { await store.refresh() }
                .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Current", systemImage: "gauge.with.dots.needle.50percent") }
            .tag(AppTab.current)

            NavigationStack {
                page { UsageHistoryView(history: store.history) }
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("History", systemImage: "chart.bar.fill") }
            .tag(AppTab.history)

            NavigationStack {
                page { SettingsView(store: store) }
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(AppTab.settings)
        }
        .tint(.synPurple)
        .toolbarBackground(Color.synPaper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .task {
            if store.snapshot == nil { await store.refresh() }
        }
    }

    private func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            DotBackground()
            ScrollView {
                content()
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 32)
            }
        }
        .foregroundStyle(Color.synInk)
    }
}

private struct CurrentHeader: View {
    let store: UsageStore

    var body: some View {
        HStack(alignment: .center) {
            Text("SynView")
                .font(.synWordmark(size: 48))
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color.synPlannerInk)
                    .frame(width: 49, height: 49)
                    .background(Color.synYellow)
                    .clipShape(Circle())
                    .background {
                        Circle()
                            .fill(Color.synShadow)
                            .offset(x: 4, y: 5)
                    }
                    .overlay(Circle().strokeBorder(Color.synOutline, lineWidth: 2.25))
            }
            .buttonStyle(.plain)
            .disabled(store.isLoading)
            .rotationEffect(.degrees(store.isLoading ? 18 : 0))
            .accessibilityLabel(store.isLoading ? "Refreshing usage" : "Reload usage")
        }
        .padding(.horizontal, 2)
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
                .frame(maxWidth: .infinity)
                .padding(.top, 70)
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
    @AppStorage(UsageLayout.storageKey) private var storedLayout = UsageLayout.bars.rawValue

    private var layout: UsageLayout { UsageLayout(rawValue: storedLayout) ?? .bars }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("TODAY’S CHECK-IN ✿")
                .font(.system(.headline, design: .rounded, weight: .black))
                .tracking(0.5)
                .padding(.horizontal, 17)
                .padding(.vertical, 11)
                .background(Color.synPink)
                .stickerBorder(cornerRadius: 10, offset: 5)
                .rotationEffect(.degrees(-1.5))

            if let rolling = snapshot.rollingFiveHourLimit,
               let weekly = snapshot.weeklyTokenLimit {
                if layout == .bars {
                    QuotaBarsCard(weekly: weekly, rolling: rolling, lastUpdated: lastUpdated)
                } else {
                    QuotaRingsCard(weekly: weekly, rolling: rolling, lastUpdated: lastUpdated)
                }
                WeeklyPlannerCard(limit: weekly)
            } else if let subscription = snapshot.subscription {
                LegacyLedgerCard(quota: subscription, lastUpdated: lastUpdated)
            }
        }
    }
}

private struct QuotaBarsCard: View {
    let weekly: WeeklyTokenLimit
    let rolling: RollingFiveHourLimit
    let lastUpdated: Date?

    private var state: QuotaAccessState {
        QuotaAccessState(weeklyRemaining: weekly.remaining, requestRemaining: rolling.remaining)
    }

    var body: some View {
        VStack(spacing: 0) {
            GateStatusBadge(state: state)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)

            DashedDivider()

            GateBarSection(
                icon: "diamond",
                iconColor: .synYellow,
                iconForeground: .synPlannerInk,
                title: "Weekly credits",
                subtitle: "Long-term spending budget",
                value: weekly.remaining.formatted(.currency(code: "USD")),
                maximum: "of \(weekly.maximum.formatted(.currency(code: "USD")))",
                progress: ratio(weekly.remaining, weekly.maximum),
                fill: .synWeeklyFill,
                refill: "+\(weekly.refillAmount.formatted(.currency(code: "USD"))) every 3h 22m"
            )

            AndBadge()
                .padding(.vertical, -1)
                .zIndex(1)

            GateBarSection(
                icon: "clock",
                iconColor: .synBlue,
                title: "Five-hour requests",
                subtitle: "Short-term request capacity",
                value: format(rolling.remaining),
                maximum: "of \(format(rolling.max))",
                progress: ratio(rolling.remaining, rolling.max),
                fill: .synRequestFill,
                refill: "+\(format(rolling.refillAmount)) every 15m"
            )

            DashedDivider()
            NextRefillBand(weekly: weekly, rolling: rolling, lastUpdated: lastUpdated)
        }
        .background(Color.synPaper)
        .stickerBorder(cornerRadius: 24, offset: 7)
        .accessibilityElement(children: .contain)
    }
}

private struct GateBarSection: View {
    let icon: String
    let iconColor: Color
    var iconForeground = Color.synInk
    let title: String
    let subtitle: String
    let value: String
    let maximum: String
    let progress: Double
    let fill: Color
    let refill: String

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 13) {
                Stamp(icon: icon, color: iconColor, foreground: iconForeground, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.synMuted)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(value)
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .minimumScaleFactor(0.75)
                    Text(maximum)
                        .font(.caption.bold())
                        .foregroundStyle(Color.synMuted)
                }
            }

            SegmentedQuotaBar(progress: progress, fill: fill)
                .padding(.leading, 61)

            Text(refill)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Color.synMuted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value) \(maximum), \(refill)")
    }
}

private struct SegmentedQuotaBar: View {
    let progress: Double
    let fill: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.synInk.opacity(0.11))

                Rectangle()
                    .fill(fill)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))

                HStack(spacing: 0) {
                    ForEach(1..<10, id: \.self) { _ in
                        Spacer()
                        Rectangle()
                            .fill(Color.synOutline.opacity(0.54))
                            .frame(width: 1.5)
                    }
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.synOutline, lineWidth: 2))
        }
        .frame(height: 18)
    }
}

private struct QuotaRingsCard: View {
    let weekly: WeeklyTokenLimit
    let rolling: RollingFiveHourLimit
    let lastUpdated: Date?

    private var state: QuotaAccessState {
        QuotaAccessState(weeklyRemaining: weekly.remaining, requestRemaining: rolling.remaining)
    }

    var body: some View {
        VStack(spacing: 0) {
            GateStatusBadge(state: state)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)

            DashedDivider()

            HStack(alignment: .top, spacing: 8) {
                QuotaRing(
                    title: "Weekly credits",
                    subtitle: "of \(weekly.maximum.formatted(.currency(code: "USD")))",
                    value: weekly.remaining.formatted(.currency(code: "USD")),
                    progress: ratio(weekly.remaining, weekly.maximum),
                    color: .synWeeklyFill,
                    refill: "+\(weekly.refillAmount.formatted(.currency(code: "USD"))) / 3h 22m"
                )

                AndBadge()
                    .rotationEffect(.degrees(-4))
                    .padding(.top, 51)

                QuotaRing(
                    title: "Five-hour requests",
                    subtitle: "of \(format(rolling.max))",
                    value: format(rolling.remaining),
                    progress: ratio(rolling.remaining, rolling.max),
                    color: .synRequestFill,
                    refill: "+\(format(rolling.refillAmount)) / 15m"
                )
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 22)

            DashedDivider()
            NextRefillBand(weekly: weekly, rolling: rolling, lastUpdated: lastUpdated)
        }
        .background(Color.synPaper)
        .stickerBorder(cornerRadius: 24, offset: 7)
    }
}

private struct QuotaRing: View {
    let title: String
    let subtitle: String
    let value: String
    let progress: Double
    let color: Color
    let refill: String

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.synInk.opacity(0.10), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text(value)
                        .font(.system(.headline, design: .rounded, weight: .black))
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.synMuted)
                }
                .padding(13)
            }
            .frame(width: 114, height: 114)

            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(refill)
                .font(.caption2.bold())
                .foregroundStyle(Color.synMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value) \(subtitle), \(refill)")
    }
}

private struct GateStatusBadge: View {
    let state: QuotaAccessState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(state.isReady ? Color.synRequestFill : Color.synWeeklyFill)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.synOutline.opacity(0.45), lineWidth: 1))
            Text(state.title.uppercased())
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .tracking(0.7)
        }
        .foregroundStyle(colorScheme == .dark && state.isReady ? Color.synInk : Color.synPlannerInk)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(state.isReady ? Color.synMint : Color.synYellow)
        .notebookOutline(cornerRadius: 22)
        .accessibilityElement(children: .combine)
    }
}

private struct AndBadge: View {
    var body: some View {
        Text("AND")
            .font(.system(.caption, design: .rounded, weight: .black))
            .tracking(0.6)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(Color.synPaper)
            .notebookOutline(cornerRadius: 18)
            .accessibilityHidden(true)
    }
}

private struct NextRefillBand: View {
    let weekly: WeeklyTokenLimit
    let rolling: RollingFiveHourLimit
    let lastUpdated: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(spacing: 13) {
                Stamp(icon: "clock.arrow.circlepath", color: .synMint, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NEXT REFILL")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.synMuted)
                    Text(nextRefillText(now: context.date))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
                Spacer()
                if let lastUpdated {
                    Text(lastUpdated, format: .dateTime.hour().minute())
                        .font(.caption2.bold())
                        .foregroundStyle(Color.synMuted)
                        .accessibilityLabel("Last checked \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.synPurple.opacity(0.10))
        }
    }

    private func nextRefillText(now: Date) -> String {
        let weeklyDate = weekly.nextRefillDate ?? .distantFuture
        let rollingDate = rolling.nextTickDate ?? .distantFuture
        if weeklyDate < rollingDate {
            return "+\(weekly.refillAmount.formatted(.currency(code: "USD"))) in \(countdown(to: weeklyDate, now: now))"
        }
        return "+\(format(rolling.refillAmount)) requests in \(countdown(to: rollingDate, now: now))"
    }
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
                    .tracking(0.7)

                HStack(alignment: .firstTextBaseline) {
                    Text("Weekly Reserve")
                        .font(.system(.title2, design: .rounded, weight: .black))
                    Spacer()
                    Text(percent(limit.percentRemaining / 100))
                        .font(.system(.subheadline, design: .rounded, weight: .black))
                }

                Text("Weekly credits refill by \(limit.refillAmount.formatted(.currency(code: "USD"))) every 3h 22m.")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))

                HStack(spacing: 9) {
                    RefillFact(
                        label: "NEXT REFILL",
                        value: "+\(limit.refillAmount.formatted(.currency(code: "USD"))) in \(countdown(to: limit.nextRefillDate, now: context.date))"
                    )
                    RefillFact(
                        label: "AVAILABLE NOW",
                        value: limit.remaining.formatted(.currency(code: "USD"))
                    )
                }

                if limit.remaining < limit.maximum, limit.refillAmount > 0 {
                    DashedDivider(color: Color.synPlannerInk.opacity(0.34))

                    HStack {
                        Text("Target reserve")
                            .font(.subheadline.bold())
                        Spacer()
                        Text(target, format: .currency(code: "USD"))
                            .font(.system(.headline, design: .rounded, weight: .black))
                    }

                    Slider(value: $target, in: limit.remaining...limit.maximum, step: limit.refillAmount)
                        .tint(.synPurple)
                        .accessibilityLabel("Target weekly reserve")

                    Label(
                        "About \(duration(limit.timeToReach(target, now: context.date))) without new usage",
                        systemImage: "clock"
                    )
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
            }
            .foregroundStyle(Color.synPlannerInk)
            .padding(19)
            .background(Color.synYellow)
            .stickerBorder(cornerRadius: 20, offset: 7)
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
        VStack(alignment: .leading, spacing: 22) {
            Text("YOUR WEEK SO FAR ✿")
                .font(.system(.headline, design: .rounded, weight: .black))
                .tracking(0.6)
                .padding(.horizontal, 17)
                .padding(.vertical, 11)
                .background(Color.synPink)
                .stickerBorder(cornerRadius: 10, offset: 5)
                .rotationEffect(.degrees(-1.2))

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RECENT CHECK-INS")
                        .font(.caption.bold())
                        .tracking(0.8)
                        .foregroundStyle(Color.synMuted)
                    Text("History")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .accessibilityAddTraits(.isHeader)
                    Text("Saved quota snapshots, newest first.")
                        .font(.subheadline)
                        .foregroundStyle(Color.synMuted)
                }
                Spacer()
                rangePicker
            }

            if visibleHistory.isEmpty {
                EmptyHistoryView()
            } else {
                historyChart
                activitySummary
            }

            Text("History starts with your first check-in and stays on this device.")
                .font(.footnote)
                .foregroundStyle(Color.synMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 3) {
            rangeButton(7)
            rangeButton(30)
        }
        .padding(3)
        .background(Color.synPaper)
        .notebookOutline(cornerRadius: 11)
    }

    private var historyChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WEEKLY CREDITS AVAILABLE")
                .font(.caption.bold())
                .tracking(0.6)
                .foregroundStyle(Color.synMuted)

            Chart(visibleHistory) { item in
                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Credits", item.weeklyRemaining),
                    width: .ratio(0.64)
                )
                .foregroundStyle(barColor(for: item.date))
                .cornerRadius(7)
                .annotation(position: .top) {
                    Text(item.weeklyRemaining, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.caption2.bold())
                        .foregroundStyle(Color.synInk)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .foregroundStyle(Color.synOutline.opacity(0.24))
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 206)
        }
        .padding(19)
        .background(Color.synPaper)
        .stickerBorder(cornerRadius: 22, offset: 7)
    }

    private var activitySummary: some View {
        HStack(spacing: 12) {
            SummaryCard(
                label: "MOST IN RESERVE",
                value: dayName(visibleHistory.max { $0.weeklyRemaining < $1.weeklyRemaining }?.date),
                color: .synMint,
                rotation: -1.5
            )
            SummaryCard(
                label: "LEAST IN RESERVE",
                value: dayName(visibleHistory.min { $0.weeklyRemaining < $1.weeklyRemaining }?.date),
                color: .synBlue,
                rotation: 1.4
            )
        }
    }

    private func rangeButton(_ value: Int) -> some View {
        Button(value == 7 ? "7D" : "30D") { days = value }
            .font(.caption.bold())
            .foregroundStyle(Color.synInk)
            .padding(.horizontal, 9)
            .frame(minHeight: 44)
            .background(days == value ? Color.synYellow : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .accessibilityAddTraits(days == value ? .isSelected : [])
    }

    private func barColor(for date: Date) -> Color {
        let colors: [Color] = [.synPink, .synYellow, .synMint, .synBlue, .synPink, .synYellow, .synMint]
        return colors[(Calendar.current.component(.weekday, from: date) - 1) % colors.count]
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
    var foreground = Color.synInk
    var size: CGFloat = 39

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.synOutline, lineWidth: 2))
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
                .foregroundStyle(Color.synPlannerInk.opacity(0.68))
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .padding(11)
        .background(Color.white.opacity(0.55))
        .notebookOutline(cornerRadius: 11)
    }
}

private struct SummaryCard: View {
    let label: String
    let value: String
    let color: Color
    let rotation: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.caption2.bold())
                .tracking(0.4)
                .foregroundStyle(Color.synInk.opacity(0.72))
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .black))
                .foregroundStyle(Color.synInk)
        }
        .frame(maxWidth: .infinity, minHeight: 73, alignment: .leading)
        .padding(15)
        .background(color)
        .stickerBorder(cornerRadius: 17, offset: 5)
        .rotationEffect(.degrees(rotation))
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

private func ratio(_ value: Double, _ maximum: Double) -> Double {
    maximum > 0 ? value / maximum : 0
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
