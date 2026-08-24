# Allotment — Rename, Theme, and Provider-Flow Redesign

**Date:** 2026-08-24
**Status:** Approved design, ready for implementation plan
**North star:** "openusage, but as an iOS app" — provider-grouped quota meters with live refill info, one layout, minimal settings.

## 1. Rename: SynView → Allotment

### What changes

| Item | From | To |
|------|------|-----|
| `CFBundleDisplayName` | SynView | Allotment |
| `PRODUCT_NAME` | SynView | Allotment |
| Wordmark in `DashboardView` header | "SynView" | "Allotment" |
| Wordmark in `SetupView` badge | "SYNVIEW ✿" | "ALLOTMENT ✿" |
| `SettingsView` appearance copy | "Pick SynView's look…" | "Pick Allotment's look…" |

### Full rename (user decision: everything renames)

- **Bundle ID:** `com.interactivebuffoonery.synview` → `com.interactivebuffoonery.allotment` (test bundle likewise). Consequences accepted by user: new App Store Connect app record, existing TestFlight testers reinstall fresh, old record's build history is not carried over.
- **Xcode target/scheme/module names:** `SynView` → `Allotment`, `SynViewTests` → `AllotmentTests`. Source directories renamed (`SynView/` → `Allotment/`, `SynViewTests/` → `AllotmentTests/`), project.yml regenerated via XcodeGen.
- **Internal identifier prefixes:** `syn*` color names (`synInk`, `synPurple`…) → `allo*` equivalents, and `synWordmark` → `alloWordmark`. Provider-specific names that reference Synthetic-as-a-service (`SyntheticClient`, "Synthetic API Key" labels) stay — those name the provider, not the app.
- **AppStorage/UserDefaults keys** referencing the old name move to `allotment.*` keys (usage-layout key is being deleted anyway; appearance key migrates or resets — resetting is fine, it's one preference).
- Repo directory name (`synview`) can stay as-is locally; GitHub remote rename is optional and separate.
- App Store Connect: create new app record under "Allotment" before next submission.

## 2. Theme

- **Accent color:** purple → leaf green. Existing theme already carries it as `synRequestFill` (light `#47B08C`, dark `#61C29E`). AccentColor.colorset updated to match; TabView tint moves from `.synPurple` to green.
- **Weekly credits bar:** gold fill (`synWeeklyFill`) → purple. Removes the last gold accent per reviewer feedback.
- **Refresh button:** yellow circle → purple.
- **Weekly refill planner card background:** stays yellow (it's a deliberate sticky-note moment, not an accent).
- Everything else in `Style.swift` — sticker borders, dot-grid background, shadows, card styles — untouched.

## 3. Typography

- **Wordmark font:** SF Rounded Black → **Fraunces SemiBold** (SIL Open Font License, free to embed, no attribution required).
- Implementation: bundle the static Fraunces SemiBold TTF in the app target, add to `UIAppFonts` in project.yml's info properties, change `Font.synWordmark(size:)` from `.system(..., design: .rounded)` to `.custom("Fraunces-SemiBold", size: size)`.
- Fallback: if the font fails to load, `.custom` falls back to system silently — acceptable, but verify on one TestFlight build.
- Only the wordmark uses Fraunces. Data, labels, and numbers stay in SF (legibility beats charm for quota figures).

## 4. App icon

- New seedling icon, direction B from the brainstorm session: two-leaf sprout on a soil line, sticker style (thick ink outline, offset shadow feel) on warm paper background.
- Replaces `AppIcon.png` (1024px) — the only asset changed.

## 5. Launch screen

- Static (iOS launch screens cannot animate): dot-grid blue background, centered seedling mark, "Allotment" in Fraunces. Should visually match the app's first real frame so the transition is invisible.
- Implemented as a storyboard-free `UILaunchScreen` with background color + centered image; wordmark text via image if Fraunces isn't available in launch screen context (launch screens can only use bundled resources — include a pre-rendered PNG of the lockup).

## 6. Setup flow (multi-provider ready)

Replaces single-screen `SetupView` with a two-step flow. The pattern: **one picker, one key screen, reused everywhere** — new providers are new rows, never new screens.

**Step 1 — Provider picker (first launch)**
- Seedling + Allotment wordmark header.
- Headline: "Connect a provider". Subhead: "Track your AI limits, refills, and history from your iOS device."
- Rows: **Synthetic** (active, tappable), **Codex** (greyed, chip "COMING SOON"), **More providers** (greyed, chip "COMING SOON").

**Step 2 — Key entry**
- Header shows chosen provider (icon + name + "Connect your account"), back link "‹ providers".
- Existing key-entry UI stays: secure field (`syn_…`), Keychain copy ("Your key stays in this device's Keychain."), validation, error messaging, auto-focus.
- CTA: "Save provider".

**Data model:** introduce a `Provider` enum (`.synthetic` for now) as the seam for Codex later. `APIKeyStore` gains provider-scoped keys (`apikey.<provider>`). No Codex implementation — only the model seam and the disabled row.

## 7. Settings

- Stays named **Settings** (tab and header).
- API-key card becomes a **Providers** section: one row per connected provider ("Synthetic — key on this device") with chevron → key-entry screen, plus a dashed **Add provider** row that opens the step-1/2 flow. For now, "Add provider" over an already-connected Synthetic just opens key update.
- Section header above the cards: keeps the existing "MAKE IT YOURS" kicker and "Settings" title.
- **Layout picker deleted entirely** — see §8.
- **iCloud section (placeholder):** a dimmed card labeled "iCloud Sync" with a "COMING SOON" chip and copy — "Sync providers, keys, and history across your devices." Non-functional; no entitlements yet.
- **Sync design (decided now, built later):** two channels.
  - **Keys:** synced via **iCloud Keychain** (`kSecAttrSynchronizable = true` on key items). This is genuinely secure — iCloud Keychain is end-to-end encrypted (it's how Safari passwords sync); keys never touch App-CloudKit storage. Offered as an **opt-in toggle** ("Sync via iCloud Keychain") so users who want per-device keys keep that behavior. Default: off.
  - **History & settings:** synced via **CloudKit** (private database) or `NSUbiquitousKeyValueStore` for the small settings surface. Provider connections sync, so a "connected" state appears on all devices — but without key sync opted in, a second device shows the provider and prompts for its key.
- Appearance card stays (System/Light/Dark) with copy updated to "Allotment".
- Disconnect becomes "Disconnect Synthetic" per-provider row (destructive), unchanged behavior.

## 8. Current tab: bars only

- **Delete the Rings layout**: `QuotaRingsCard`, `UsageLayout` enum, its `@AppStorage` key, the layout picker UI and previews. `CurrentUsageView` renders `QuotaBarsCard` unconditionally.
- Card anatomy stays: weekly credits + five-hour requests bars, AND badge, next-refill band, gate status badge, weekly refill planner.
- **Multi-provider shape (structural change now, UI benefit at Codex):** quota section becomes "one card per provider, stacked". With one provider connected the Current tab is visually identical to today. When Codex lands, its card appends below. Refactor so the card takes a `Provider` + its snapshot instead of assuming `store.snapshot` is Synthetic-global.
- The refresh button lives in the header and refreshes all connected providers (today: one).

## 9. Copy rules (garden = visual, never vocabulary)

Words that survive as garden identity: the name **Allotment**, the seedling icon, the ✿/✦ flourishes already in the app, the green accent, Fraunces.

Explicitly NOT used anywhere: plot, bed, shed, till, sow, grow, harvest, water. Every label is functional ("Connect a provider", "Save provider", "Providers", "Settings"). Data (numbers, percentages, refill times) stays literal everywhere — no exceptions.

## 10. Out of scope

- Codex (or any second provider) integration — only the model seam and the COMING SOON row.
- iCloud sync implementation — only the settings placeholder and the sync design decision.
- History chart changes, planner-card changes, iPad layout changes.
- haptic/sound/animated-transitions work.

## 11. Verification

- Rename: build + run, confirm display name on home screen and in-app wordmarks.
- Font: Fraunces visibly distinct on TestFlight build (silent fallback risk otherwise).
- Setup: fresh install → picker → Synthetic key → dashboard. Keychain persistence across relaunch.
- Settings: Providers section round-trips key update and disconnect.
- Bars-only: `UsageLayout` removed, no rings remnant; existing `AppStorage` key simply orphaned (harmless).
- Existing test suite passes; update tests referencing deleted layout/provider assumptions.
