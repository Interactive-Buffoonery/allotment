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
        ZStack {
            DotBackground()
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
            .tint(.alloRequestFill)
            .toolbarBackground(Color.alloPaper, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .task {
                if store.snapshot == nil { await store.refresh() }
            }
        }
    }

    private func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 32)
        }
        .foregroundStyle(Color.alloInk)
    }
}

private struct CurrentHeader: View {
    let store: UsageStore

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Allotment")
                    .font(.alloWordmark(size: 44))
                    .accessibilityAddTraits(.isHeader)
                Text("QUOTA NOTEBOOK")
                    .font(.caption.bold())
                    .tracking(0.6)
                    .foregroundStyle(Color.alloMuted)
                    .accessibilityHidden(true)
            }

            Spacer()

            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color.alloStickerInk)
                    .frame(width: 47, height: 47)
                    .background(Color.alloPurple)
                    .clipShape(Circle())
                    .background {
                        Circle()
                            .fill(Color.alloInkShadow)
                            .offset(x: 3, y: 3)
                    }
                    .overlay(Circle().strokeBorder(Color.alloOutline, lineWidth: 2))
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

    var body: some View {
        if let snapshot = store.snapshot {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(alignment: .leading, spacing: 24) {
                    if store.errorMessage != nil {
                        StaleDataBanner()
                    }
                    CurrentUsageView(
                        snapshot: snapshot,
                        lastUpdated: store.lastUpdated,
                        now: context.date,
                        refresh: { Task { await store.refresh() } }
                    )
                }
                .task(id: isRefillDue(snapshot: snapshot, now: context.date)) {
                    if isRefillDue(snapshot: snapshot, now: context.date), !store.isLoading {
                        await store.refresh()
                    }
                }
            }
        } else if store.isLoading {
            ProgressView("Checking Synthetic…")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.alloInk)
                .tint(.alloInk)
                .frame(maxWidth: .infinity)
                .padding(.top, 70)
        } else {
            EmptyUsageView(
                message: store.errorMessage ?? "No quota data is available yet.",
                retry: { Task { await store.refresh() } },
                isError: store.errorMessage != nil
            )
        }
    }

    private func isRefillDue(snapshot: QuotaResponse, now: Date) -> Bool {
        let weekly = snapshot.weeklyTokenLimit?.nextRefillDate ?? .distantFuture
        let rolling = snapshot.rollingFiveHourLimit?.nextTickDate ?? .distantFuture
        return weekly < now || rolling < now
    }
}

private struct StaleDataBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .accessibilityHidden(true)
            Text("Couldn't refresh — showing last known data.")
                .font(.caption.bold())
        }
        .foregroundStyle(Color.alloError)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.alloError.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.alloError.opacity(0.4), lineWidth: 1.5))
    }
}

private struct CurrentUsageView: View {
    let snapshot: QuotaResponse
    let lastUpdated: Date?
    let now: Date
    let refresh: () -> Void
    @AppStorage(UsageLayout.storageKey) private var storedLayout = UsageLayout.bars.rawValue
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: UsageLayout { UsageLayout(rawValue: storedLayout) ?? .bars }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("TODAY'S CHECK-IN ✿")
                .font(.system(.headline, design: .rounded, weight: .black))
                .tracking(0.5)
                .padding(.horizontal, 17)
                .padding(.vertical, 11)
                .background(Color.alloPink)
                .stickerBorder(shadow: .alloInkShadow, cornerRadius: 10, offset: 5)
                .rotationEffect(.degrees(-2))
                .accessibilityLabel("Today's check-in")
                .accessibilityAddTraits(.isHeader)

            if let rolling = snapshot.rollingFiveHourLimit,
               let weekly = snapshot.weeklyTokenLimit {
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 24) {
                        quotaCard(weekly: weekly, rolling: rolling)
                        WeeklyPlannerCard(limit: weekly, now: now)
                    }
                } else {
                    quotaCard(weekly: weekly, rolling: rolling)
                    WeeklyPlannerCard(limit: weekly, now: now)
                }
            } else if let subscription = snapshot.subscription {
                LegacyLedgerCard(quota: subscription, lastUpdated: lastUpdated)
            } else {
                EmptyUsageView(
                    message: "Synthetic didn't return any quota details.",
                    retry: refresh,
                    isError: true
                )
            }
        }
    }

    private func quotaCard(weekly: WeeklyTokenLimit, rolling: RollingFiveHourLimit) -> some View {
        Group {
            if layout == .bars {
                QuotaBarsCard(weekly: weekly, rolling: rolling, lastUpdated: lastUpdated, now: now)
            } else {
                QuotaRingsCard(weekly: weekly, rolling: rolling, lastUpdated: lastUpdated, now: now)
            }
        }
    }
}

private struct QuotaBarsCard: View {
    let weekly: WeeklyTokenLimit
    let rolling: RollingFiveHourLimit
    let lastUpdated: Date?
    let now: Date

    private var state: QuotaAccessState {
        QuotaAccessState(weeklyRemaining: weekly.remaining, requestRemaining: rolling.remaining)
    }

    var body: some View {
        let weeklyRemainingUSD = weekly.remaining.formatted(.currency(code: "USD"))
        let weeklyMaximumUSD = weekly.maximum.formatted(.currency(code: "USD"))
        let weeklyRefillUSD = weekly.refillAmount.formatted(.currency(code: "USD"))

        VStack(spacing: 0) {
            if !state.isReady {
                GateStatusBadge(state: state)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)

                DashedDivider()
            }

            GateBarSection(
                icon: "diamond",
                iconColor: .alloMauve,
                iconForeground: .alloStickerInk,
                title: "Weekly credits",
                subtitle: "Long-term spending budget",
                value: weeklyRemainingUSD,
                maximum: "of \(weeklyMaximumUSD)",
                progress: ratio(weekly.remaining, weekly.maximum),
                fill: .alloPurple,
                refill: "+\(weeklyRefillUSD) every 3h 22m"
            )

            AndBadge()
                .padding(.vertical, -1)
                .zIndex(1)

            GateBarSection(
                icon: "clock",
                iconColor: .alloBlue,
                title: "Five-hour requests",
                subtitle: "Short-term request capacity",
                value: format(rolling.remaining),
                maximum: "of \(format(rolling.max))",
                progress: ratio(rolling.remaining, rolling.max),
                fill: .alloRequestFill,
                refill: "+\(format(rolling.refillAmount)) every 15m"
            )

            DashedDivider()
            NextRefillBand(weekly: weekly, rolling: rolling, lastUpdated: lastUpdated, now: now)
        }
        .background(Color.alloPaper)
        .stickerBorder(cornerRadius: 24, offset: 7)
        .accessibilityElement(children: .contain)
    }
}

private struct GateBarSection: View {
    let icon: String
    let iconColor: Color
    var iconForeground = Color.alloInk
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
                        .foregroundStyle(Color.alloMuted)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(value)
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .minimumScaleFactor(0.75)
                    Text(maximum)
                        .font(.caption.bold())
                        .foregroundStyle(Color.alloMuted)
                }
            }

            SegmentedQuotaBar(progress: progress, fill: fill)
                .padding(.leading, 61)

            Text(refill)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Color.alloMuted)
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
        Canvas { context, size in
            let clamped = min(max(progress, 0), 1)
            let fillWidth = size.width * clamped

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.alloInk.opacity(0.11)))

            if fillWidth > 0 {
                var fillRect = CGRect(origin: .zero, size: size)
                fillRect.size.width = fillWidth
                context.fill(Path(fillRect), with: .color(fill))
            }

            let segmentWidth = size.width / 10
            for i in 1..<10 {
                let x = segmentWidth * CGFloat(i)
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Color.alloOutline.opacity(0.54)), lineWidth: 1.5)
            }
        }
        .frame(height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.alloOutline, lineWidth: 2))
    }
}

private struct QuotaRingsCard: View {
    let weekly: WeeklyTokenLimit
    let rolling: RollingFiveHourLimit
    let lastUpdated: Date?
    let now: Date
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var state: QuotaAccessState {
        QuotaAccessState(weeklyRemaining: weekly.remaining, requestRemaining: rolling.remaining)
    }

    private var ringSize: CGFloat { sizeClass == .compact ? 94 : 114 }

    var body: some View {
        let weeklyMaximumUSD = weekly.maximum.formatted(.currency(code: "USD"))
        let weeklyRemainingUSD = weekly.remaining.formatted(.currency(code: "USD"))
        let weeklyRefillUSD = weekly.refillAmount.formatted(.currency(code: "USD"))

        VStack(spacing: 0) {
            if !state.isReady {
                GateStatusBadge(state: state)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)

                DashedDivider()
            }

            HStack(alignment: .top, spacing: 8) {
                QuotaRing(
                    title: "Weekly credits",
                    subtitle: "of \(weeklyMaximumUSD)",
                    value: weeklyRemainingUSD,
                    progress: ratio(weekly.remaining, weekly.maximum),
                    color: .alloPurple,
                    refill: "+\(weeklyRefillUSD) / 3h 22m",
                    size: ringSize
                )

                AndBadge()
                    .rotationEffect(.degrees(-4))
                    .padding(.top, sizeClass == .compact ? 42 : 51)

                QuotaRing(
                    title: "Five-hour requests",
                    subtitle: "of \(format(rolling.max))",
                    value: format(rolling.remaining),
                    progress: ratio(rolling.remaining, rolling.max),
                    color: .alloRequestFill,
                    refill: "+\(format(rolling.refillAmount)) / 15m",
                    size: ringSize
                )
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 22)

            DashedDivider()
            NextRefillBand(weekly: weekly, rolling: rolling, lastUpdated: lastUpdated, now: now)
        }
        .background(Color.alloPaper)
        .stickerBorder(cornerRadius: 24, offset: 7)
        .accessibilityElement(children: .contain)
    }
}

private struct QuotaRing: View {
    let title: String
    let subtitle: String
    let value: String
    let progress: Double
    let color: Color
    let refill: String
    var size: CGFloat = 114

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.alloInk.opacity(0.10), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text(value)
                        .font(.system(.headline, design: .rounded, weight: .black))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.alloMuted)
                }
                .padding(10)
            }
            .frame(width: size, height: size)

            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(refill)
                .font(.caption2.bold())
                .foregroundStyle(Color.alloMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value) \(subtitle), \(refill)")
    }
}

private struct GateStatusBadge: View {
    let state: QuotaAccessState

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(state.isReady ? Color.alloRequestFill : Color.alloPurple)
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(Color.alloOutline.opacity(0.45), lineWidth: 1))
            Text(state.title.uppercased())
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .tracking(0.7)
        }
        .foregroundStyle(Color.alloStickerInk)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(state.isReady ? Color.alloMint : Color.alloMauve)
        .stickerBorder(shadow: .alloInkShadow, cornerRadius: 22, offset: 3)
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
            .background(Color.alloPaper)
            .stickerBorder(shadow: .alloInkShadow, cornerRadius: 18, offset: 3)
            .accessibilityHidden(true)
    }
}

private struct NextRefillBand: View {
    let weekly: WeeklyTokenLimit
    let rolling: RollingFiveHourLimit
    let lastUpdated: Date?
    let now: Date

    var body: some View {
        HStack(spacing: 13) {
            Stamp(icon: "clock.arrow.circlepath", color: .alloMint, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT REFILL")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.alloMuted)
                Text(nextRefillText(now: now))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            }
            Spacer()
            if let lastUpdated {
                Text(lastUpdated, format: lastUpdatedFormat(lastUpdated))
                    .font(.caption2.bold())
                    .foregroundStyle(Color.alloMuted)
                    .accessibilityLabel("Last checked \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.alloPurple.opacity(0.10))
    }

    private func lastUpdatedFormat(_ date: Date) -> Date.FormatStyle {
        if Calendar.current.isDateInToday(date) {
            return .dateTime.hour().minute()
        }
        return .dateTime.hour().minute().month().day()
    }

    private func nextRefillText(now: Date) -> String {
        let weeklyDate = weekly.nextRefillDate ?? .distantFuture
        let rollingDate = rolling.nextTickDate ?? .distantFuture
        if weeklyDate < rollingDate {
            return refillDueText(amount: weekly.refillAmount.formatted(.currency(code: "USD")), date: weekly.nextRefillDate, now: now)
        }
        return refillDueText(amount: format(rolling.refillAmount), date: rolling.nextTickDate, now: now)
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
                    .foregroundStyle(Color.alloMuted)
                Text("\(format(max(0, quota.limit - quota.requests))) / \(format(quota.limit))")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(21)
            DashedDivider()
            LedgerRow(icon: "arrow.up.right", color: .alloMint, label: "USED CAPACITY", value: format(quota.requests), trailing: percent(quota.requests / max(1, quota.limit)))
            Divider().padding(.leading, 72)
            LedgerRow(icon: "checkmark", color: .alloPink, label: "LAST CHECKED", value: lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "Just now", trailing: "LIVE")
        }
        .background(Color.alloPaper)
        .stickerBorder(cornerRadius: 22)
    }
}

private struct WeeklyPlannerCard: View {
    let limit: WeeklyTokenLimit
    let now: Date
    @State private var target: Double

    init(limit: WeeklyTokenLimit, now: Date) {
        self.limit = limit
        self.now = now
        _target = State(initialValue: min(limit.maximum, limit.remaining + limit.refillAmount * 8))
    }

    var body: some View {
        let remainingUSD = limit.remaining.formatted(.currency(code: "USD"))
        let maximumUSD = limit.maximum.formatted(.currency(code: "USD"))
        let refillUSD = limit.refillAmount.formatted(.currency(code: "USD"))

        VStack(alignment: .leading, spacing: 15) {
            Text("WEEKLY REFILL PLANNER ✦")
                .font(.caption.bold())
                .tracking(0.7)
                .accessibilityLabel("Weekly refill planner")
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("AVAILABLE NOW")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.alloStickerInk.opacity(0.85))
                    Text(remainingUSD)
                        .font(.system(.title2, design: .rounded, weight: .black))
                    Text("of \(maximumUSD)")
                        .font(.caption.bold())
                        .foregroundStyle(Color.alloStickerInk.opacity(0.85))
                }
                Spacer()
                let pct = percent(limit.percentRemaining / 100)
                Text(pct)
                    .font(.system(.subheadline, design: .rounded, weight: .black))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.alloMint)
                    .stickerBorder(shadow: .alloInkShadow, cornerRadius: 9, offset: 3)
                    .rotationEffect(.degrees(2))
                    .accessibilityLabel("\(pct) remaining")
            }

            HStack(spacing: 9) {
                RefillFact(
                    label: "NEXT REFILL",
                    value: refillDueText(amount: refillUSD, date: limit.nextRefillDate, now: now)
                )
                RefillFact(
                    label: "REFILL SPEED",
                    value: "+\(refillUSD) every \(duration(WeeklyTokenLimit.regenerationInterval))"
                )
            }

            if limit.remaining < limit.maximum, limit.refillAmount > 0 {
                DashedDivider(color: Color.alloStickerInk.opacity(0.34))

                HStack {
                    Text("I want available")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(target, format: .currency(code: "USD"))
                        .font(.system(.headline, design: .rounded, weight: .black))
                }

                Slider(value: $target, in: limit.remaining...limit.maximum, step: limit.refillAmount)
                    .tint(.alloPurple)
                    .accessibilityLabel("Target weekly reserve")
                    .accessibilityValue(Text(target, format: .currency(code: "USD")))

                HStack(spacing: 12) {
                    Stamp(icon: "clock", color: Color.alloPurple.opacity(0.25))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("IF YOU PAUSE NEW USAGE")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.alloStickerInk.opacity(0.85))
                        Text("You'll reach that in about \(duration(limit.timeToReach(target, now: now))).")
                            .font(.subheadline.bold())
                    }
                }
            } else if limit.refillAmount > 0 {
                Label("Your weekly credits are fully regenerated.", systemImage: "sparkles")
                    .font(.subheadline.bold())
            } else if limit.remaining < limit.maximum {
                Label("Weekly refills are paused for this account.", systemImage: "pause.circle")
                    .font(.subheadline.bold())
            }
        }
        .foregroundStyle(Color.alloStickerInk)
        .padding(19)
        .background(Color.alloMauve)
        .stickerBorder(shadow: .alloInkShadow, cornerRadius: 20, offset: 6)
        .rotationEffect(.degrees(0.6))
        .onChange(of: limit) { _, newLimit in
            target = min(max(target, newLimit.remaining), newLimit.maximum)
        }
    }
}

private struct UsageHistoryView: View {
    let history: [DailySnapshot]
    @State private var days = 7
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let visibleHistory = Array(history.suffix(days))

        VStack(alignment: .leading, spacing: 22) {
            Text("YOUR WEEK SO FAR ✿")
                .font(.system(.headline, design: .rounded, weight: .black))
                .tracking(0.6)
                .padding(.horizontal, 17)
                .padding(.vertical, 11)
                .background(Color.alloPink)
                .stickerBorder(shadow: .alloInkShadow, cornerRadius: 10, offset: 5)
                .rotationEffect(.degrees(-1.7))
                .accessibilityLabel("Your week so far")
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RECENT CHECK-INS")
                        .font(.caption.bold())
                        .tracking(0.8)
                        .foregroundStyle(Color.alloMuted)
                    Text("History")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .accessibilityAddTraits(.isHeader)
                    Text("Saved quota snapshots, oldest to newest.")
                        .font(.subheadline)
                        .foregroundStyle(Color.alloMuted)
                }
                Spacer()
                rangePicker
            }

            if visibleHistory.isEmpty {
                EmptyHistoryView()
            } else {
                historyChart(visibleHistory)
                if visibleHistory.count >= 2 {
                    activitySummary(visibleHistory)
                }
            }

            Text("History starts with your first check-in and stays on this device.")
                .font(.footnote)
                .foregroundStyle(Color.alloMuted)
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
        .background(Color.alloPaper)
        .notebookOutline(cornerRadius: 11)
    }

    private func historyChart(_ visibleHistory: [DailySnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WEEKLY CREDITS AVAILABLE")
                .font(.caption.bold())
                .tracking(0.6)
                .foregroundStyle(Color.alloMuted)

            Chart(visibleHistory) { item in
                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Credits", item.weeklyRemaining),
                    width: .ratio(0.64)
                )
                .foregroundStyle(Self.chartColor(for: item.date))
                .cornerRadius(7)
                .annotation(position: .top) {
                    let label = Text(item.weeklyRemaining, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.caption2.bold())
                    if colorScheme == .dark {
                        label
                            .foregroundStyle(Color.alloStickerInk)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.alloMauve, in: RoundedRectangle(cornerRadius: 5))
                            .padding(.bottom, 3)
                    } else {
                        label.foregroundStyle(Color.alloInk)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .foregroundStyle(Color.alloOutline.opacity(0.24))
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.short))
                }
            }
            .frame(height: 206)
        }
        .padding(19)
        .background(Color.alloPaper)
        .stickerBorder(cornerRadius: 22, offset: 7)
        .rotationEffect(.degrees(-0.5))
    }

    private func activitySummary(_ visibleHistory: [DailySnapshot]) -> some View {
        HStack(spacing: 12) {
            SummaryCard(
                label: "MOST IN RESERVE",
                value: dayName(visibleHistory.max { $0.weeklyRemaining < $1.weeklyRemaining }?.date),
                color: .alloMint,
                rotation: -1.5
            )
            SummaryCard(
                label: "LEAST IN RESERVE",
                value: dayName(visibleHistory.min { $0.weeklyRemaining < $1.weeklyRemaining }?.date),
                color: .alloPink,
                rotation: 1.4
            )
        }
    }

    private func rangeButton(_ value: Int) -> some View {
        Button(value == 7 ? "7D" : "30D") { days = value }
            .font(.caption.bold())
            .foregroundStyle(Color.alloInk)
            .padding(.horizontal, 9)
            .frame(minHeight: 44)
            .background(days == value ? Color.alloMauve : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .accessibilityAddTraits(days == value ? .isSelected : [])
    }

    private static let chartDayColors: [Color] = [
        Color.adaptive(light: .rgb(0.80, 0.32, 0.52), dark: .rgb(1.0, 0.68, 0.82)),
        Color.adaptive(light: .rgb(0.62, 0.48, 0.10), dark: .rgb(0.776, 0.627, 0.965)),
        Color.adaptive(light: .rgb(0.12, 0.50, 0.38), dark: .rgb(0.65, 0.90, 0.78)),
        Color.adaptive(light: .rgb(0.10, 0.38, 0.58), dark: .rgb(0.73, 0.93, 1.0)),
        Color.adaptive(light: .rgb(0.80, 0.32, 0.52), dark: .rgb(1.0, 0.68, 0.82)),
        Color.adaptive(light: .rgb(0.62, 0.48, 0.10), dark: .rgb(0.776, 0.627, 0.965)),
        Color.adaptive(light: .rgb(0.12, 0.50, 0.38), dark: .rgb(0.65, 0.90, 0.78)),
    ]

    private static func chartColor(for date: Date) -> Color {
        chartDayColors[(Calendar.current.component(.weekday, from: date) - 1) % chartDayColors.count]
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
                    .foregroundStyle(Color.alloMuted)
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
    var foreground = Color.alloStickerInk
    var size: CGFloat = 39

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.alloOutline, lineWidth: 2))
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
                .foregroundStyle(Color.alloStickerInk.opacity(0.85))
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .padding(11)
        .background(Color.alloPaper.opacity(0.66))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Color.alloStickerInk.opacity(0.85), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 11))
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
                .foregroundStyle(Color.alloStickerInk.opacity(0.8))
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .black))
                .foregroundStyle(Color.alloStickerInk)
        }
        .frame(maxWidth: .infinity, minHeight: 73, alignment: .leading)
        .padding(15)
        .background(color)
        .stickerBorder(cornerRadius: 17, offset: 5)
        .rotationEffect(.degrees(rotation))
    }
}

private struct DashedDivider: View {
    var color = Color.alloMuted.opacity(0.4)

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
    var isError: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "cloud.sun")
                .font(.largeTitle)
                .accessibilityHidden(true)
            Text(message)
                .multilineTextAlignment(.center)
            Button("Try Again", action: retry)
                .font(.headline)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(isError ? Color.alloError.opacity(0.15) : Color.alloMauve)
        .stickerBorder(cornerRadius: 18)
    }
}

private struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .accessibilityHidden(true)
            Text("No history yet")
                .font(.system(.headline, design: .rounded, weight: .bold))
            Text("Your first successful check-in will start the chart.")
                .font(.subheadline)
                .foregroundStyle(Color.alloMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.alloPaper)
        .stickerBorder(cornerRadius: 20)
    }
}

private func ratio(_ value: Double, _ maximum: Double) -> Double {
    maximum > 0 ? value / maximum : 0
}

private func format(_ value: Double) -> String {
    Int(value.rounded()).formatted()
}

private func percent(_ ratio: Double) -> String {
    ratio.formatted(.percent.precision(.fractionLength(0)))
}

private func countdown(to date: Date?, now: Date) -> String {
    guard let date else { return "soon" }
    return duration(max(0, date.timeIntervalSince(now)))
}

private func refillDueText(amount: String, date: Date?, now: Date) -> String {
    guard let date else { return "+\(amount) soon" }
    if date <= now { return "+\(amount) refilling now" }
    return "+\(amount) in \(countdown(to: date, now: now))"
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
