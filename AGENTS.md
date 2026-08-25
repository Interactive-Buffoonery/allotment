# Allotment

SwiftUI iOS 17 app, XcodeGen-generated project (`project.yml` is the source of truth).

## Workflow rules

- After adding/deleting files or changing `project.yml`, run `xcodegen generate` — new files are otherwise silently excluded from the target.
- Test: `xcodebuild -scheme Allotment -destination 'platform=iOS Simulator,name=iPhone 17' test`

## Releasing to TestFlight

1. Bump `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in `project.yml`, run `xcodegen generate`, commit.
2. `fastlane beta` (archives, uploads, attaches the build to the "Initial Testing" internal group).

Fastlane gotchas (all hit before, don't rediscover):

- Run with `LANG=en_US.UTF-8` or fastlane's error reporter crashes on xcodebuild's UTF-8 output.
- Needs unsandboxed keychain access for signing.
- Auth is the ASC API key (Admin role) in `fastlane/Fastfile` — never downgrade below Admin; lesser roles fail profile creation with "Cloud signing permission error".
- gym `export_method` stays `"app-store"` despite xcodebuild's deprecation warning.
- `fastlane distribute version:X.Y.Z build:N` attaches an already-uploaded build to the group; its trailing external-review error after internal attach succeeds is harmless.
