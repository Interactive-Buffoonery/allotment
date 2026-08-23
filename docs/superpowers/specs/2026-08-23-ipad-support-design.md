# Native iPad Support (Adaptive Layout)

**Date:** 2026-08-23
**Status:** Approved

## Goal

Ship SynView as a native iPad app instead of iPhone-only compatibility mode.
Ambition level: adaptive layout — size-class-aware multi-column dashboard on
iPad, no navigation architecture changes.

## Changes

### Validation

- `project.yml`: `TARGETED_DEVICE_FAMILY: "1"` → `"1,2"`.
- No orientation keys exist in `Info.plist`, so all iPad orientations are
  enabled by default. That is the desired behavior.

### Dashboard layout (`SynView/Views/DashboardView.swift`)

- Regular horizontal size class: dashboard sections lay out in two columns.
  The quota ring card and the quota navigation/access cards are side-by-side;
  wide sections (history/chart) span full width underneath.
- Compact horizontal size class: unchanged — current single-column flow is the
  fallback and continues to render exactly as today.
- Implementation: conditional `sizeClass == .compact` branches inside the
  existing `VStack` structure (the codebase already reads
  `horizontalSizeClass` in `QuotaRingsCard`). No new grid framework.

### Settings & Setup (`SettingsView.swift`, `SetupView.swift`)

- Content capped to ~700pt wide and centered in regular width so forms are
  readable instead of full-bleed stretches.

## Out of scope

- `NavigationSplitView` / sidebar
- Pointer and keyboard support
- macOS (Catalyst or Designed for iPad)
- Any data/model/service changes — layout only

## Risk & error handling

Pure layout change; no functional surface. The compact path is untouched,
so iPhone behavior cannot regress by design. Worst case is a card looking
off at a particular iPad width.

## Testing

Manual verification:

1. iPad simulator: portrait, landscape, and slide-over (compact width on
   iPad) render correctly.
2. iPhone simulator: layout unchanged from current behavior.

No unit tests — there is no logic to assert; existing `QuotaSnapshotTests`
do not touch layout.
