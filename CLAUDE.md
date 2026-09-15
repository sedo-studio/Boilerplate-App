# CLAUDE.md

Guidance for AI coding agents working in **Find My Headphones** — a small iOS
utility that helps people locate misplaced AirPods and other Bluetooth
headphones using signal strength.

This file is the source of truth for how the project is structured. It is
written against the actual code in this repo. Where the README and the code
disagree, the code (and this file) win.

---

## 1. What this app is

A focused, single-purpose finder:

1. **Onboarding** (3 screens) — what it does, what it honestly cannot do, then
   the Bluetooth permission ask.
2. **Detect** (free) — scan and confirm "Found nearby". No distance, no
   direction. This is the free proof that the app works.
3. **Paywall #1** — one-time `radar_unlock` purchase, shown straight after the
   found-nearby moment.
4. **Radar** (paid) — a pulsing proximity dial driven by smoothed RSSI, with
   warmer/colder copy.
5. **Paywall #2** — `left_behind_alerts` subscription, offered separately from
   Settings and as a soft prompt after a successful find.
6. **Settings** — saved device, both purchases, restore, alerts opt-in, legal.

- **Language / UI:** Swift 5.9, SwiftUI, async/await.
- **Min deployment:** iOS 16.0.
- **Project generation:** XcodeGen from `project.yml` (the `.xcodeproj` is
  generated, not hand-edited).
- **Architecture:** protocol-first services in a struct DI container, plus a
  small number of `@MainActor` observable managers for stateful hardware and
  purchase concerns.
- **No backend, no accounts.** Everything runs on-device. The only network
  calls are RevenueCat's and TelemetryDeck's.

### The honesty rule (read this before writing any user-facing copy)

AirPods have **no U1 / UWB chip**. Neither Apple's Find My nor any third-party
app can show a real direction arrow for them. This app works from Bluetooth
signal strength (RSSI), which supports "warmer/colder" and coarse proximity
buckets — nothing more.

So: **never** write copy, name a symbol, or design a view that implies a
bearing, a heading, an arrow pointing at the device, or a distance in metres.
"Getting warmer", "Very close", "Found nearby" are the vocabulary. This is a
product decision, not a stylistic one — it is the main thing separating this
app from the over-promising competition.

### Other golden rules

1. **Never hardcode colors, fonts, or spacing.** Use the design system:
   `DS.accent`, `DS.Colors.textPrimary`, `DS.Spacing.lg`, `DS.Radius.md`,
   `.appFont(.headline)`, `.dsCard()`. See [Design system](#5-design-system).
2. **Never put user-facing text inline.** Add a key to
   `Resources/Base.lproj/Localizable.strings` **and** `Resources/en.lproj/`,
   then use `String(localized:)` or `Text("key")`.
3. **Never construct services in a View.** Read them from
   `@Environment(\.container)` or the injected `@EnvironmentObject`s.
4. **Respect feature flags.** A flagged feature's UI must disappear when its
   flag is off — including any background work it starts.
5. **Keep the project SDK-optional.** Wrap third-party SDK code in
   `#if canImport(...)` with a working fallback, so the app compiles with no
   packages linked.
6. **Never edit the `.xcodeproj`.** It is generated from `project.yml` and is
   gitignored. Anything set in Xcode's UI — signing team, bundle id, build
   settings — is wiped on the next `xcodegen generate`. Change `project.yml`
   instead; that is where `DEVELOPMENT_TEAM` and the bundle id live.
7. **`Config/Secrets.swift` is gitignored and generated.** Never commit it. The
   committed template is `Config/Secrets.sample.swift`.
8. **There are no `__PLACEHOLDER__` tokens.** App identity is fixed in
   `AppConfig.swift`, the palette in `DesignSystem.swift`, signing and bundle
   id in `project.yml`. `setup.sh` only writes `Secrets.swift` — it never
   rewrites a tracked file, which is what keeps `git pull` clean.

---

## 2. Build, generate, and test

There is usually no Xcode toolchain in an agent environment, so you generally
**cannot build or run the simulator** — reason about correctness from the code.
When a real toolchain is available:

```bash
xcodegen generate            # after changing project.yml or adding files

xcodebuild -project FindMyHeadphones.xcodeproj -scheme FindMyHeadphones \
  -destination 'platform=iOS Simulator,name=iPhone 15' build

xcodebuild -project FindMyHeadphones.xcodeproj -scheme FindMyHeadphones \
  -destination 'platform=iOS Simulator,name=iPhone 15' test
```

- **Adding a `.swift` file:** XcodeGen globs whole folders (`Config`, `Core`,
  `Modules`, `Resources`). Drop the file in the right folder and run
  `xcodegen generate` — never hand-edit the `pbxproj`.
- **Tests** live in `Tests/` (XCTest, `@testable import FindMyHeadphones`). The
  finder's logic is deliberately split into pure value types
  (`FinderModels.swift`) so it is testable without CoreBluetooth or a device.
  **Bluetooth behaviour itself cannot be unit-tested or simulated** — the
  simulator has no Bluetooth stack. Anything touching `BluetoothFinder` needs a
  physical device, so keep decision logic out of it and in the models.

---

## 3. Directory map

```
Config/
  AppConfig.swift        # app name, bundle id, feature flags, legal links
  FeatureFlags.swift     # the 4 flags
  Secrets.sample.swift   # template; Secrets.swift is generated + gitignored

Core/
  Root/                  # @main entry (FindMyHeadphonesApp) + RootView (TabView)
  Routing/               # AppRoute + AppRouter
  DI/                    # DIContainer (struct) + environment plumbing
  Services/              # PurchasesService, Entitlements, RatingService
  Analytics/             # AnalyticsService + event-name constants
  Theme/                 # the design system
  Logging/               # AppLogger
  Utils/                 # AppEvents (Notification.Name)

Modules/
  Finder/                # THE PRODUCT — CoreBluetooth engine + detect + radar
  LeftBehind/            # disconnect monitor + when-to-offer policy
  Paywall/               # shared paywall layout + the two paywalls
  Reminders/             # local-notification plumbing (alert delivery)
  Onboarding/            # 3-screen intro ending in the Bluetooth ask
  Review/                # App Store review prompt
  Settings/              # settings screen

Resources/               # Assets, Info.plist, Base.lproj + en.lproj
Tests/                   # XCTest unit tests
setup.sh                 # writes Secrets.swift + runs xcodegen (keys only)
project.yml              # XcodeGen spec — signing, bundle id, Info.plist
```

---

## 4. Architecture

### Dependency injection

`Core/DI/DIContainer.swift` is a `Sendable` struct with exactly three things:

```swift
public struct DIContainer: Sendable {
    public var config: AppConfig
    public var purchasesService: PurchasesService
    public var analytics: AnalyticsService
}
```

`makeDefault()` is the composition root: it picks `RevenueCatPurchasesService`
vs `LocalPurchasesService` (by linked SDK + present key) and TelemetryDeck vs
noop analytics. Inject with `.inject(container)`, read with
`@Environment(\.container)`.

### Observable app state

Three `@MainActor` `ObservableObject`s carry live state that a struct container
cannot:

| Object | Injected as | Owns |
|---|---|---|
| `AppRouter` | `@EnvironmentObject` (root) | navigation path |
| `Entitlements` | `@EnvironmentObject` (root) | what the user has bought |
| `BluetoothFinder.shared` | singleton | the one `CBCentralManager` |
| `LeftBehindMonitor.shared` | singleton | disconnect watch + alert arming |
| `ReminderScheduler.shared` | singleton | notification permission + delivery |

The singletons exist because iOS gives us one Bluetooth stack and one
notification centre; two instances would fight. Everything else goes through
the container.

### Navigation

`AppRoute` has a single case, `.radar`. Both paywalls are **sheets**, not
routes, because they are interruptions rather than destinations. `RootView` is
a `TabView` (Find + Settings) with a `NavigationStack` on the Find tab.

---

## 5. Design system

All theming flows from `Core/Theme/DesignSystem.swift` (the `DS` namespace).

| Need | Use |
|---|---|
| Brand color | `DS.primary` (lilac), `DS.accent` (periwinkle) |
| Proximity temperature | `DS.cool` → `DS.warm`, mixed with `DS.Colors.blend` |
| Status | `DS.success`, `DS.warning`, `DS.danger`, `DS.info` |
| Text | `DS.Colors.textPrimary` / `.textSecondary` / `.textTertiary` |
| Spacing | `DS.Spacing.xs sm md lg xl xxl xxxl` |
| Radius | `DS.Radius.none xs sm md lg xl xxl full` |
| Motion | `DS.Motion.fast/.normal/.slow`, `DS.Motion.spring` |

Typography: never call `.font(...)` with a system font — use `.appFont(_:)`
with an `AppTextStyle` case, and `DSEyebrow` for the small tracked uppercase
label above a heading. Surfaces: `.dsCard()`, `.dsCardContent()`, `.dsInput()`,
`DSPrimaryButtonStyle()` and friends.

**The look:** dark-first (the app defaults to dark and the neutral scale is
indigo-tinted, not grey), translucent `.glass` cards over a slow drifting
`AnimatedBackground`, and soft blurred glows rather than hard strokes. When
adding a lit element, reach for a blurred radial gradient plus a coloured
shadow — that is the visual language the radar and the finder cards share.

---

## 6. The finder (`Modules/Finder`)

This is the part worth understanding properly.

- **`FinderModels.swift`** — pure value types: `DiscoveredDevice`,
  `ProximityLevel`, `ProximityTrend`, `FinderState`, `HeadphoneHeuristic` and
  `RSSISmoother`. All unit-tested. Put new decision logic here.
- **`BluetoothFinder.swift`** — the single `CBCentralManager` owner. It is
  `@MainActor`; CoreBluetooth delegate callbacks are `nonisolated` shims that
  hop back with `Task { @MainActor in … }`.
- **`FinderDetectView.swift`** — free scan + "Found nearby" + troubleshooting.
- **`RadarView.swift`** — the paid dial.

### How it finds things (and the limits)

- Public CoreBluetooth only. We deliberately **do not** decode Apple's
  undocumented proximity-pairing advertisements — it is fragile and breaks on
  OS updates.
- Three sources of signal, in order of reliability:
  1. `retrieveConnectedPeripherals(withServices:)` — devices already connected
     for audio. They never appear in a scan, so this is checked first and is
     the fastest route to "found nearby".
  2. A GATT connection plus `readRSSI()` polling — keeps working when the
     device stops advertising.
  3. Advertisement RSSI from an `allowDuplicates` scan.
- `rssi` on `DiscoveredDevice` is **optional on purpose**. A device we know
  about but have not measured has `nil` — never a stand-in number. Do not
  "fix" this by defaulting it.
- RSSI is noisy. `RSSISmoother` keeps a fast and a slow EMA and calls the trend
  from the gap between them, and refuses to report a direction until it has
  four samples.

### Left-behind alerts (`Modules/LeftBehind`)

A disconnect arms a notification `graceSeconds` in the future; a reconnect
cancels it. The app keeps a pending CoreBluetooth connection open so iOS wakes
it for connection events in the background — that is what the
`bluetooth-central` background mode in `project.yml` is for.

**Known limitation, documented in the UI:** putting AirPods in their case looks
identical to walking away. The grace period and the rate limit are what keep
that from being annoying; if you change either, keep that trade-off in mind.

---

## 7. Monetization

Two entitlements, sold independently, never bundled into one tiered screen:

| Entitlement | Type | Price | Unlocks |
|---|---|---|---|
| `radar_unlock` | non-consumable | $9.99 | the radar screen, forever |
| `left_behind_alerts` | auto-renewing subscription | $4.99/mo | proactive alerts |

Identifiers live in `AppEntitlement` (`Core/Services/PurchasesService.swift`)
and are asserted in tests — a typo locks paying customers out. Each entitlement
is served by a RevenueCat **offering of the same name**. See
`documentation/MONETIZATION.md`.

`LocalPurchasesService` is the fallback when RevenueCat is unlinked or
unkeyed. It grants purchases **only in DEBUG** — a release build with a missing
key sells nothing rather than giving the app away.

---

## 8. Feature flags

`Config/FeatureFlags.swift` — four flags, all defaulting to `true`:

| Flag | Meaning |
|---|---|
| `onboarding` | show the first-run intro |
| `radarUnlock` | sell the radar; `false` makes it free for everyone |
| `leftBehindAlerts` | the alerts feature and its subscription |
| `reviewPrompt` | ask for a review after a successful find |

The finder itself is never flagged — it is the app. Flags are edited directly
in `AppConfig.default`; nothing generates that line.

---

## 9. Analytics

Event names are constants in `Core/Analytics/AnalyticsEvents.swift`. The funnel
the app is judged on: detection success rate, paywall #1 view→purchase, paywall
#2 view→purchase (tracked separately), and review prompts tied to real finds.
Renaming a constant breaks the historical series in TelemetryDeck.

---

## 10. Conventions cheat-sheet

- **Concurrency:** UI-touching services are `@MainActor`; cross-boundary types
  are `Sendable`. CoreBluetooth delegate methods are `nonisolated` + hop.
- **Previews:** keep `PreviewProvider`s working — they rely on
  `LocalPurchasesService` and must not need live keys.
- **SF Symbols** for icons.
- **Match the neighbours.** Open the closest existing file and mirror its
  structure, naming, and comment density before adding a new one.
