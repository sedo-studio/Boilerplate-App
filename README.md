<h1 align="center">Find My Headphones</h1>

<p align="center">
  <strong>A small iOS utility that tells you whether your AirPods are nearby — and how close you're getting.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.9+-F05138?style=flat&logo=swift&logoColor=white" alt="Swift 5.9+" />
  <img src="https://img.shields.io/badge/iOS-16+-000000?style=flat&logo=apple&logoColor=white" alt="iOS 16+" />
  <img src="https://img.shields.io/badge/SwiftUI-4+-0A84FF?style=flat" alt="SwiftUI" />
</p>

---

## What it does

| Step | Screen | Costs |
|---|---|---|
| 1 | Onboarding — what it does, what it can't do, Bluetooth permission | free |
| 2 | **Detect** — scan, and confirm "Found nearby" | free |
| 3 | **Radar** — pulsing proximity dial with warmer/colder guidance | $9.99 once |
| 4 | **Left-behind alerts** — a notification when you walk off without them | $4.99/month |

The two purchases are independent. Buying the radar never enrols you in a
subscription, and the subscription never re-sells the radar.

## What it deliberately does not do

AirPods contain no U1 / ultra-wideband chip. **No app can show a direction
arrow for them** — not this one, and not Apple's own Find My. Anything that
claims otherwise is showing you an animation, not a bearing.

So this app reports Bluetooth signal strength: "found nearby", "very close",
"getting warmer". It cannot tell you which way to walk, it cannot give you a
distance in metres, and it cannot find headphones that are switched off, flat,
or shut inside a case that has stopped them broadcasting. All of that is said
plainly in the app itself, not buried here.

## Getting started

```bash
brew install xcodegen     # once
./setup.sh                # writes Config/Secrets.swift, generates the project
open FindMyHeadphones.xcodeproj
```

`setup.sh` only asks for API keys. Leave both blank and the app still runs —
purchases fall back to a local stub in debug builds and analytics go no-op.
With keys already set, `xcodegen generate` on its own is enough.

> **Bluetooth needs a real device.** The iOS Simulator has no Bluetooth stack,
> so the finder does nothing there. Everything else — onboarding, paywalls,
> settings — works in the simulator, and without a RevenueCat key debug builds
> use a local purchase stub so you can walk the whole flow.

## Configuration

- `Config/AppConfig.swift` — app name, bundle id, feature flags, legal links.
- `Config/FeatureFlags.swift` — `onboarding`, `radarUnlock`, `leftBehindAlerts`,
  `reviewPrompt`. Turning `radarUnlock` off makes the radar free, which is handy
  for TestFlight builds and App Review screenshots.
- `Core/Theme/DesignSystem.swift` — every colour, spacing and radius token.
- `project.yml` — signing team, bundle id, Info.plist keys. The `.xcodeproj` is
  generated from it and gitignored, so edit this rather than Xcode's UI.
- `Config/Secrets.swift` — RevenueCat and TelemetryDeck keys. Generated,
  gitignored, never committed.

## Store setup

Two RevenueCat entitlements, each served by an offering of the same name:

| Entitlement | Product type | Price |
|---|---|---|
| `radar_unlock` | non-consumable | $9.99 |
| `left_behind_alerts` | auto-renewing subscription | $4.99/month |

Full walkthrough in [`documentation/MONETIZATION.md`](documentation/MONETIZATION.md).
App Store listing guidance, including the trademark rules around "AirPods", is
in [`documentation/ASO.md`](documentation/ASO.md).

## Permissions

| Permission | Why | Where |
|---|---|---|
| Bluetooth (`NSBluetoothAlwaysUsageDescription`) | finding the headphones | asked at the end of onboarding |
| Notifications | left-behind alerts only | asked when the user enables alerts |
| `bluetooth-central` background mode | lets iOS wake the app on disconnect | required for left-behind alerts |

No account, no location permission, no analytics on where you are.

## Project layout

```
Config/     app configuration + secrets template
Core/       DI, routing, purchases, analytics, theme
Modules/    Finder (the product), LeftBehind, Paywall, Onboarding, Settings, …
Resources/  assets, Info.plist, strings
Tests/      unit tests for the finder's pure logic
```

Architecture notes and the rules for contributing live in
[`CLAUDE.md`](CLAUDE.md).

## Tests

```bash
xcodebuild -project FindMyHeadphones.xcodeproj -scheme FindMyHeadphones \
  -destination 'platform=iOS Simulator,name=iPhone 15' test
```

The signal-smoothing, proximity-bucketing, device-matching and paywall-timing
logic is all pure value types, so it is covered by unit tests. The CoreBluetooth
layer itself needs a physical device.
