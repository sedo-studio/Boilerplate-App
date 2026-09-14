<p align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="The Swift Kit Pro" />
</p>

<h1 align="center">The Swift Kit Pro</h1>

<p align="center">
  <strong>The production-ready SwiftUI boilerplate — Pro tier. Everything in The Swift Kit, plus the advanced features real apps ship with.</strong>
</p>

<p align="center">
  Clone. Run <code>./setup.sh</code>. Ship.<br/>
  Auth, payments, AI streaming, widgets, gamification, onboarding quizzes, camera/OCR, reminders — all wired up, all flag-gated, all removable in one line.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.9+-F05138?style=flat&logo=swift&logoColor=white" alt="Swift 5.9+" />
  <img src="https://img.shields.io/badge/iOS-16+-000000?style=flat&logo=apple&logoColor=white" alt="iOS 16+" />
  <img src="https://img.shields.io/badge/Xcode-15+-147EFB?style=flat&logo=xcode&logoColor=white" alt="Xcode 15+" />
  <img src="https://img.shields.io/badge/SwiftUI-4+-0A84FF?style=flat" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Tier-PRO-8A2BE2?style=flat" alt="Pro" />
  <img src="https://img.shields.io/badge/License-Commercial-8A2BE2?style=flat" alt="License" />
</p>

---

## What makes this the Pro tier

The Swift Kit Pro is a superset of [The Swift Kit](https://theswiftk.it.com). You get the entire base kit — auth, paywalls, AI backend, onboarding, analytics, theming, caching — and **13 additional Pro features**, each one self-contained, flag-gated, and grounded in what shipping apps actually need.

Every Pro feature follows the same rule:

> **One flag to disable it. One folder to delete it. Zero impact on anything else.**

Flip the flag in `Config/FeatureFlags.swift`, delete the matching `Modules/<Feature>/` folder, and the feature is gone — the rest of the app keeps building.

---

## Quick Start

One script configures everything:

```bash
chmod +x setup.sh
./setup.sh
```

The interactive wizard walks you through app name, bundle ID, theme colors, **which Pro features to keep**, API keys, and legal URLs. It replaces every placeholder across the project, toggles your chosen feature flags, regenerates the Xcode project, and generates `Config/Secrets.swift` automatically.

For CI or non-interactive usage:

```bash
./setup.sh --config setup-config.json
```

Then open the project in Xcode, select your team under Signing, and hit Run. The first launch (in DEBUG) opens the **Test Drive** hub so you can tap through every feature, including a dedicated **Pro Features** section.

> **Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen).** `project.yml` is the source of truth. After adding or removing files, run `xcodegen generate` before building. `setup.sh` runs it for you.

---

## Pro Features

Each feature is a `Bool` flag in `Config/FeatureFlags.swift`, enabled in `AppConfig.default`, lives in its own folder, and has a demo entry in `Modules/Demo/TestDriveView.swift`. To remove one: set its flag to `false` **and** delete its folder.

| Feature | What it does | Flag | Folder |
|---------|--------------|------|--------|
| **AI PRO (streaming chat)** | Token-by-token streaming chat with persisted history, backed by the Flask SSE endpoint. Works with OpenAI **or** Gemini. Falls back to an offline mock stream when no backend is running. | `aiPro` | `Modules/AIPro/` |
| **Widgets + Live Activities** | Home/lock-screen WidgetKit widget, a Live Activity, and Dynamic Island support — shipped as a separate embedded app-extension target. | `widgets` | `Widgets/` |
| **Gamification** | XP, levels, badges, and streaks with level-up / badge-unlock celebration overlays. Persisted to UserDefaults. | `gamification` | `Modules/Gamification/` |
| **Questionnaire Onboarding** | A config-driven quiz/survey onboarding flow (single- and multi-select), progress bar, and persisted answers. | `questionnaireOnboarding` | `Modules/QuestionnaireOnboarding/` |
| **Camera + Scanner + OCR** | VisionKit document scanner, Vision text recognition (OCR), and a PhotosUI image picker. | `camera` | `Modules/Capture/` |
| **Reminders / Local Notifications** | Daily reminders, streak-protection nudges, and one-off test notifications via `UNUserNotificationCenter`. No server needed. | `reminders` | `Modules/Reminders/` |
| **SwiftData Store** | An offline-first CRUD store built on SwiftData (`@Model` / `@Query`). Availability-gated to iOS 17. | `swiftDataStore` | `Modules/SwiftDataStore/` |
| **Paywall Templates** | 10 premium, conversion-focused paywall designs + a preview gallery. One `PaywallContent` model drives all copy; `DS.*` drives all visuals. | `paywallTemplates` | `Modules/PaywallTemplates/` |
| **Swift Charts** | A ready-to-customize Swift Charts demo screen. | `charts` | `Modules/Charts/` |
| **Review Prompt** | Native `SKStoreReviewController` request plus a custom pre-prompt, triggered after N significant events. | `reviewPrompt` | `Modules/Review/` |
| **In-App Feedback** | A category + message feedback form with an offline-friendly service. | `inAppFeedback` | `Modules/Feedback/` |
| **Biometric App Lock** | Opt-in Face ID / Touch ID lock gate. Fails open if no biometrics are enrolled. | `biometricLock` | `Modules/AppLock/` |
| **Localization** | A runtime in-app language picker that switches `Localizable.strings` without a restart. Ships `en`, `es`, `hi`. | `localization` | `Modules/Localization/` |

---

## What's Included (base kit)

| Module | Description | Key Files |
|--------|-------------|-----------|
| **Authentication** | Email/password + Sign in with Apple via Supabase | `Modules/Auth/` |
| **Onboarding** | 3 swappable styles (Carousel, Highlights, Minimal) | `Modules/Onboarding/` |
| **Paywalls** | RevenueCat + StoreKit 2 integration with paywall UI | `Modules/Paywall/` |
| **AI Features** | Chat, image generation, and vision via the Flask backend | `Modules/Home/`, `Backend/Python/` |
| **Analytics** | TelemetryDeck with automatic event tracking | `Core/Analytics/` |
| **Notifications** | Local + remote push notifications with debug UI | `Core/Notifications/` |
| **Profile Setup** | Avatar upload, user data capture, Supabase storage | `Modules/Profile/` |
| **Settings** | Dark mode, subscription management, account deletion | `Modules/Settings/` |
| **Caching** | Ultra-modular, actor-based caching system | `Core/Cache/` |
| **Theming** | Design tokens, color system, glass effects, custom fonts | `Core/Theme/` |
| **Local Data** | CoreData demo with full CRUD | `Modules/Demo/` |

---

## Project Structure

```
the-swift-kit-pro/
├── Config/                         # App configuration
│   ├── AppConfig.swift             # App name, backend, feature flags, legal URLs
│   ├── FeatureFlags.swift          # 20 flags — toggle any module on/off
│   └── Secrets.sample.swift        # API key template (setup.sh → Secrets.swift)
│
├── Core/                           # Core infrastructure
│   ├── Cache/                      # Modular caching system (actor-based)
│   ├── DI/                         # Dependency injection container
│   ├── Routing/                    # Navigation router (typed enum routes)
│   ├── Services/                   # AI client, purchases, Apple Sign-In, rating
│   ├── Theme/                      # Design tokens, colors, typography, fonts
│   ├── Analytics/                  # Analytics service wrapper
│   ├── Notifications/              # Push & local notification handling
│   ├── Persistence/                # CoreData stack
│   ├── Root/                       # App entry point & RootView
│   └── Utils/                      # App events
│
├── Modules/                        # Feature modules (base + PRO)
│   ├── Auth/  Onboarding/  Home/  Paywall/  Profile/  Settings/  Notifications/
│   ├── Demo/                       # Test Drive hub (PRO feature shortcuts)
│   ├── Charts/                     # PRO — Swift Charts
│   ├── Review/                     # PRO — review prompt
│   ├── Feedback/                   # PRO — in-app feedback
│   ├── AppLock/                    # PRO — biometric app lock
│   ├── Localization/               # PRO — runtime language switch
│   ├── PaywallTemplates/           # PRO — 10 premium paywalls + gallery
│   ├── Gamification/               # PRO — XP / levels / badges / streaks
│   ├── QuestionnaireOnboarding/    # PRO — quiz onboarding
│   ├── Capture/                    # PRO — camera / scanner / OCR
│   ├── Reminders/                  # PRO — local notifications
│   ├── SwiftDataStore/             # PRO — SwiftData CRUD (iOS 17)
│   └── AIPro/                      # PRO — streaming chat + history
│
├── Widgets/                        # PRO — widget app-extension target
│   ├── Shared/                     # ActivityAttributes + controller (shared w/ app)
│   └── TheSwiftKitWidgets.swift    # WidgetBundle: widget + Live Activity
│
├── Backend/                        # Server-side code & protocols
│   ├── Protocols/                  # Repository interfaces
│   ├── Supabase/                   # Supabase implementations + setup.sql
│   └── Python/                     # Flask AI backend (OpenAI or Gemini)
│
├── Resources/                      # Assets, icons, fonts, localization (.lproj)
├── setup.sh                        # Interactive setup wizard (20 flags)
├── setup-config.json               # Non-interactive config template
└── project.yml                     # XcodeGen configuration
```

---

## Architecture

The Swift Kit Pro follows **MVVM with Dependency Injection** and a protocol-first design:

```
SwiftUI View  →  ViewModel (@MainActor)  →  DIContainer  →  Repository Protocol  →  Backend Implementation
```

**Key design principles:**

- **Protocol-based repositories** — Every backend service (auth, profiles, subscriptions) has a protocol. Swap implementations by changing one line in `AppConfig`.
- **Feature flags** — Toggle any module without touching code. 20 flags total: 7 base + 13 Pro.
- **Self-contained Pro modules** — Each Pro feature lives in its own folder and is intentionally **not** wired into the DIContainer (it uses view-local state or a `.shared` singleton) so deleting the folder never breaks the graph.
- **Conditional imports** — The project compiles even without Supabase, RevenueCat, or TelemetryDeck SDKs linked. Missing SDKs gracefully fall back to no-op implementations.
- **Actor-based concurrency** — Repositories and the caching layer use Swift actors for thread safety.
- **Centralized theming** — Change two hex values in the design system to rebrand the entire app, including every Pro screen and paywall.

---

## Configuration

### Feature Flags (`Config/FeatureFlags.swift`)

| Flag | Tier | Description |
|------|------|-------------|
| `onboarding` | Base | Show onboarding flow on first launch |
| `auth` | Base | Require authentication |
| `paywall` | Base | Show paywall after onboarding |
| `notifications` | Base | Request notification permissions |
| `aiFeatures` | Base | AI chat / image / vision on the home screen |
| `appleSignIn` | Base | Show Sign in with Apple button |
| `enableCaching` | Base | Wrap repositories in cached decorators |
| `charts` | Pro | Swift Charts demo |
| `reviewPrompt` | Pro | App Store review prompt |
| `inAppFeedback` | Pro | In-app feedback form |
| `biometricLock` | Pro | Face ID / Touch ID app lock |
| `localization` | Pro | Runtime in-app language switch |
| `paywallTemplates` | Pro | 10 premium paywall templates + gallery |
| `widgets` | Pro | Widgets + Live Activities |
| `questionnaireOnboarding` | Pro | Quiz/survey onboarding |
| `gamification` | Pro | XP, levels, badges, streaks |
| `aiPro` | Pro | Streaming chat + persisted history |
| `camera` | Pro | Camera + document scanner + OCR |
| `reminders` | Pro | Local reminder scheduling |
| `swiftDataStore` | Pro | SwiftData offline store (iOS 17) |

### Secrets (`Config/Secrets.swift`)

Created automatically by `setup.sh`, or manually from `Secrets.sample.swift`. Never committed — `Secrets.swift` is gitignored.

| Key | Required | Source |
|-----|----------|--------|
| `supabaseURL` | Yes | Supabase project settings |
| `supabaseAnonKey` | Yes | Supabase project settings |
| `revenueCatAPIKey` | For payments | RevenueCat dashboard |
| `telemetryDeckAppID` | For analytics | TelemetryDeck dashboard |
| `aiBackendBaseURLString` | For AI / AI PRO | Your Flask server URL |

### Theming

- **Colors**: Set the primary/accent hex values in the design system (`Core/Theme/`).
- **Fonts**: Drop `.ttf`/`.otf` into `Resources/Fonts/`, register them in `FontRegistry.swift`. All views use `.appFont()`.
- **Typography & surfaces**: `DS.*` tokens (`DS.Spacing`, `DS.Radius`, `DS.primary`, `.dsCard()`) drive every screen, including Pro features and paywalls.

---

## Backend Setup (AI + AI PRO)

The Flask backend is **provider-agnostic**: set `LLM_PROVIDER=openai` or `LLM_PROVIDER=gemini`.

```bash
cd Backend/Python
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env     # set LLM_PROVIDER + OPENAI_API_KEY or GEMINI_API_KEY
python app.py            # runs on port 5001
```

Endpoints:

| Endpoint | Purpose |
|----------|---------|
| `/v1/chat` | Standard chat completion |
| `/v1/chat/stream` | **Server-Sent Events streaming** — powers AI PRO |
| `/v1/images` | Image generation |
| `/v1/vision` | Image analysis (multimodal) |

For AI PRO, point `Secrets.aiBackendBaseURLString` at your deployed server. Until then, the chat falls back to an offline mock stream so it always demos. See `Backend/Python/README.md` for full API docs and deployment.

### Database (Supabase)

Open your Supabase project's **SQL Editor**, paste `Backend/Supabase/setup.sql`, and Run. It creates the `profiles` + `user_subscriptions` tables, RLS policies, an auto-create-profile trigger, the `avatars` storage bucket, and indexes. Idempotent.

### RevenueCat & Sign in with Apple

- **RevenueCat**: create offerings in the dashboard, paste your public key into `Secrets.revenueCatAPIKey`. The base paywall and subscription management work automatically; the Pro paywall templates wire to the same `PurchasesService` via their `onPurchase` callback.
- **Sign in with Apple**: enable the capability in Xcode, configure your App ID, enable the Apple provider in Supabase, and set `appleSignIn = true`. See `Core/Services/AppleSignInService.swift`.

---

## Widgets + Live Activities

The `widgets` feature ships as a **separate app-extension target** (`TheSwiftKitWidgets`) defined in `project.yml` and embedded in the app. Shared types (`TimerActivityAttributes`, `LiveActivityController`) live in `Widgets/Shared/` and compile into both the app and the extension.

**To go live with real data**, add an **App Group** capability to both the app and the widget target, then share data via a shared `UserDefaults`/SwiftData container. Out of the box the widget renders sample/date-based content so it builds and previews without any account setup.

**To remove the feature entirely:** flip `widgets` off, delete the `Widgets/` folder, remove the `TheSwiftKitWidgets` target + the app's `embed` dependency + the `Widgets/Shared` app source + `NSSupportsLiveActivities` in `project.yml`, then run `xcodegen generate`.

> Live Activities are `@available(iOS 16.1)` and SwiftData is `@available(iOS 17)`-gated because the base deployment target is iOS 16. Raise the deployment target if you'd rather drop the annotations.

---

## Removing a Pro feature (the one-line promise)

Take **Gamification** as an example:

1. Set `gamification: false` in `Config/AppConfig.swift` → the feature disappears from the UI immediately.
2. (Optional, to strip the code) delete the `Modules/Gamification/` folder and run `xcodegen generate`.

That's it — nothing else references the module. The same pattern holds for every Pro feature. Widgets has the one extra step of removing its extension target (see above).

---

## Development

### Test Drive (Debug Only)

`Modules/Demo/TestDriveView.swift` is the first screen in DEBUG builds. Its **Pro Features** section has a flag-gated entry for every Pro feature — gamification, reminders, questionnaire, SwiftData, camera/OCR, AI PRO chat, widgets, paywall templates, charts, feedback, language, review prompt, and a Face ID test button.

### Debug Tips

- Set `backend: .local` in `AppConfig` to develop without Supabase.
- All modules work with local fallbacks (no network required) — AI PRO mock-streams, feedback stores locally.
- Run `xcodegen generate` after adding/removing files, before building.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Packages fail to resolve | Ensure Xcode 15+. Clean DerivedData (`Cmd+Shift+K`) and retry |
| `Cannot find <Type> in scope` after adding files | Run `xcodegen generate` — sources are folder-globbed |
| Supabase errors | Verify URL/key in Secrets. Check RLS policies. Test in SQL Editor |
| RevenueCat issues | Verify offerings in RC dashboard. Check sandbox account. Relaunch to refresh cache |
| AI / AI PRO errors | Confirm `LLM_PROVIDER` + the matching API key in `.env`. Check `/health`. Inspect Flask logs |
| Widget won't build | Ensure the `TheSwiftKitWidgets` target exists after `xcodegen generate`; check the bundle ID |
| Live Activity / SwiftData unavailable | Expected below iOS 16.1 / iOS 17 — they're availability-gated |
| Biometric lock blocks launch in Simulator | Enrol Face ID in the sim (Features → Face ID → Enrolled) or set `biometricLock: false` while testing |

---

## Production Checklist

- [ ] Run `./setup.sh` with production values
- [ ] Choose which Pro features to keep; delete the folders you don't ship
- [ ] Replace legal URLs with actual Privacy Policy and Terms
- [ ] Set up the Supabase database (`setup.sql`)
- [ ] Configure RevenueCat products and offerings
- [ ] Deploy the AI Flask backend and set `aiBackendBaseURLString` (for AI / AI PRO)
- [ ] Add an App Group to the app + widget targets for real widget data (if using widgets)
- [ ] Test camera/OCR, Face ID, push, and Live Activities on a **real device** (Simulator can't fully validate these)
- [ ] Provide final app icons
- [ ] Remove or hide Test Drive from release builds
- [ ] Review RLS policies and storage permissions
- [ ] Keep secrets out of git — `Secrets.swift` and `.env` are already gitignored
- [ ] Test the full flow: onboarding → auth → profile → paywall → main app

---

## Changelog

### Pro v1.0.0 — May 2026

**13 Pro features added on top of The Swift Kit base:**

- **AI PRO** — streaming chat (SSE) with persisted history; provider-agnostic Flask backend (`LLM_PROVIDER=openai|gemini`) with a new `/v1/chat/stream` endpoint; offline mock-stream fallback
- **Widgets + Live Activities** — separate embedded widget extension target, Dynamic Island support, shared activity types
- **Gamification** — XP, levels, badges, streaks with celebration overlays
- **Questionnaire onboarding** — config-driven quiz flow
- **Camera + scanner + OCR** — VisionKit + Vision + PhotosUI
- **Reminders** — local notification scheduling (daily / streak / test)
- **SwiftData store** — offline-first CRUD (iOS 17)
- **Paywall templates** — 10 premium designs + preview gallery
- **Swift Charts**, **review prompt**, **in-app feedback**, **biometric app lock**, **runtime localization** (`en`/`es`/`hi`)
- Every Pro feature flag-gated and removable by deleting one folder
- `setup.sh` extended to 20 flags with non-interactive `--config` support

### Base v1.2.0 — March 2026

- Centralized 5-layer design system (Flat, Bordered, Elevated, Glass, Liquid Glass)
- Interactive `setup.sh` configuration CLI
- Feature flags for every major module
- AI features (chat, image generation, vision) via a secure Flask proxy
- MVVM + dependency injection, protocol-based repositories, conditional SDK imports

---

<p align="center">
  Built with care for indie iOS developers.<br/>
  <a href="https://theswiftk.it.com">theswiftk.it.com</a>
</p>
