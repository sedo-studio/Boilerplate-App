# CLAUDE.md

Guidance for AI coding agents (Claude Code, and any tool that reads `CLAUDE.md`)
working in **The Swift Kit Pro** — the $199 tier of the Swift Kit SwiftUI iOS
template.

This file is the source of truth for how the project is structured and how to
extend it. It is written against the actual code in this repo, not the README.
Where the README and the code disagree, **the code (and this file) win** — the
most common example is feature-flag property names (see
[Feature flags](#feature-flags)).

> **Pro vs base.** This repo is the base kit **plus 13 flag-gated Pro features**
> plus a widget extension. Everything in the base kit still applies. The parts
> that are Pro-only are marked **PRO** throughout, and section 13 covers them in
> full. If you have read the base kit's `CLAUDE.md`, read sections
> [1](#1-what-this-project-is), [6b](#6b-where-pro-features-are-surfaced),
> [13](#13-pro-features) and [14](#14-pro-specific-footguns) — the rest is
> largely unchanged.

---

## 1. What this project is

The Swift Kit Pro is a **boilerplate** that ships the plumbing every indie iOS
app needs — auth, payments, AI, onboarding, analytics, notifications, caching,
theming — already wired together, **plus** the higher-value features most
templates leave out: streaming AI chat, widgets and Live Activities,
gamification, quiz onboarding, camera/OCR, SwiftData, 10 paywall templates,
charts, in-app feedback, biometric lock, and runtime localization.

A buyer runs `./setup.sh` once to stamp it with their app name, bundle ID, brand
colors, API keys **and which Pro features they want**, then builds on top.

- **Language / UI:** Swift 5.9, SwiftUI, `async`/`await`, Swift actors.
- **Min deployment:** iOS 16.0 (the widget extension targets **iOS 16.1**;
  SwiftData pieces are gated `@available(iOS 17, *)`).
- **Project generation:** [XcodeGen](https://github.com/yonsm/XcodeGen) from
  `project.yml` (the `.xcodeproj` is generated, not hand-edited).
- **Architecture:** MVVM + protocol-first repositories + a struct dependency
  container injected through the SwiftUI environment.
- **Backends:** Supabase (auth, profiles) and an optional Python/Flask AI proxy
  that speaks **either OpenAI or Gemini**. Everything also runs fully
  **local/offline** with in-memory fallbacks.
- **Targets:** `TheSwiftKit` (app) and **PRO** `TheSwiftKitWidgets`
  (app-extension).

### Golden rules (read before editing)

1. **Never hardcode colors, fonts, or spacing.** Always go through the design
   system: `DS.accent`, `DS.Colors.textPrimary`, `DS.Spacing.lg`,
   `DS.Radius.md`, `.appFont(.headline)`, `.dsCard()`. See
   [Design system](#5-design-system-the-one-file).
2. **Never put user-facing text inline.** Add a key to
   `Resources/Base.lproj/Localizable.strings` **and its `en`/`es`/`hi`
   counterparts** and use `String(localized:)` or `Text("key")`. See
   [Localization](#7-localization).
3. **Never construct backend services directly in a View.** Read them from
   `@Environment(\.container)` (a `DIContainer`). See
   [Dependency injection](#4b-dependency-injection-dicontainer).
4. **Respect feature flags.** A feature's UI must disappear when its flag is
   off. Pro adds 13 more flags. See [Feature flags](#feature-flags).
5. **Keep every Pro feature deletable.** A buyer must be able to remove a Pro
   feature by flipping its flag off and deleting its folder — nothing outside
   that folder may depend on it. See [The removal contract](#the-removal-contract).
6. **Keep the project SDK-optional.** Wrap third-party SDK code in
   `#if canImport(...)` with a no-op fallback so the app compiles with no
   packages linked. See [Conditional SDKs](#conditional-sdk-imports).
7. **Don't edit `TheSwiftKit.xcodeproj/`.** It is generated from `project.yml`.
   Change `project.yml` and run `xcodegen generate`.
8. **`Config/Secrets.swift` is gitignored and generated.** Never commit it and
   never read secrets from anywhere else. The committed template is
   `Config/Secrets.sample.swift`.
9. **`__PLACEHOLDER__` tokens are intentional.** Tokens like `__APP_NAME__`,
   `__PRIMARY_COLOR__` are replaced by `setup.sh`. Don't "fix" them by hand
   unless that's the explicit task, and **never commit a version with them
   already replaced** — that ships a pre-stamped template to the next buyer.

---

## 2. Build, generate, and test

There is no Xcode toolchain in most agent environments, so you usually **cannot
build or run the simulator**. Reason about correctness from the code. When a
real toolchain is available:

```bash
# Regenerate the Xcode project after changing project.yml or adding files
xcodegen generate

# Build (CLI)
xcodebuild -project TheSwiftKit.xcodeproj -scheme TheSwiftKit \
  -destination 'platform=iOS Simulator,name=iPhone 15' build

# Test (XCTest target: TheSwiftKitTests)
xcodebuild -project TheSwiftKit.xcodeproj -scheme TheSwiftKit \
  -destination 'platform=iOS Simulator,name=iPhone 15' test
```

- **Adding a new `.swift` file:** XcodeGen globs whole folders
  (`Config`, `Core`, `Modules`, `Backend`, `Resources`, **PRO** `Widgets/Shared`
  — see `project.yml`). Drop the file into the right folder and run
  `xcodegen generate`; no manual `pbxproj` editing. `Backend/Python/**` and
  `**/*.md`/`**/*.txt` under `Backend` are excluded from the app target.
- **PRO — widget sources:** files under `Widgets/` belong to the
  **`TheSwiftKitWidgets`** extension target, *except* `Widgets/Shared`, which is
  compiled into **both** the app and the extension (Live Activity attribute
  types must exist on both sides).
- **Tests** live in `Tests/` and use **XCTest** with `@testable import
  TheSwiftKit` (see `Tests/Unit/ContainerTests.swift`). Keep tests offline by
  relying on the `.local` backend / `Local*` repositories.
- **Swift Package deps** (`project.yml` → `packages`): Supabase (`2.0.0+`),
  TelemetryDeck/SwiftSDK (`1.5.1+`, product `TelemetryClient`), RevenueCat
  (`5.0.0+`).

---

## 3. Directory map

```
swift-kit-pro/
├── Config/                  # App configuration (compiled into the app)
│   ├── AppConfig.swift          # appName, bundleId, backend, layout, onboarding, branding, flags, legal
│   ├── FeatureFlags.swift       # 7 base flags + 13 PRO flags (real names live here)
│   ├── Secrets.sample.swift     # template; guarded by `#if USE_SAMPLE_SECRETS`
│   └── Secrets.swift            # GENERATED by setup.sh, GITIGNORED (may be absent)
│
├── Core/                    # Cross-cutting infrastructure (unchanged from base)
│   ├── Root/                    # @main app entry (TheSwiftKitApp), RootView, AppDelegate
│   ├── Routing/                 # AppRoute enum + AppRouter (ObservableObject)
│   ├── DI/                      # DIContainer (struct) + environment plumbing
│   ├── Theme/                   # Design system — see section 5
│   ├── Cache/                   # Actor-based caching layer — see section 8
│   ├── Services/                # AIApiClient, Purchases, AppleSignIn, Rating, AccountDeletion
│   ├── Analytics/               # AnalyticsService protocol + TelemetryDeck/Noop impls
│   ├── Notifications/           # NotificationService (local + APNs)
│   ├── Persistence/             # CoreDataStack
│   ├── Logging/                 # AppLogger
│   └── Utils/                   # AppEvents (Notification.Name), Localization helpers
│
├── Modules/                 # Feature screens (View + ViewModel + Coordinator)
│   ├── Auth/ Onboarding/ Home/ Paywall/ Profile/ Settings/ Notifications/ AI/   # base
│   ├── Demo/                    # TestDriveView — DEBUG launcher + the PRO feature hub
│   │
│   ├── AIPro/                   # PRO  streaming chat + persisted history
│   ├── AppLock/                 # PRO  Face ID / Touch ID app lock
│   ├── Capture/                 # PRO  camera + document scanner + OCR (Vision)
│   ├── Charts/                  # PRO  Swift Charts demos
│   ├── Feedback/                # PRO  in-app feedback form
│   ├── Gamification/            # PRO  XP, levels, badges, streaks
│   ├── Localization/            # PRO  runtime language switching
│   ├── PaywallTemplates/        # PRO  10 paywall templates + preview gallery
│   ├── QuestionnaireOnboarding/ # PRO  quiz-style onboarding
│   ├── Reminders/               # PRO  local reminder scheduling
│   ├── Review/                  # PRO  App Store review prompt
│   ├── SwiftDataStore/          # PRO  SwiftData offline-first store (iOS 17+)
│   └── WidgetsDemo/             # PRO  in-app explainer for the widget target
│
├── Widgets/                 # PRO  widget extension target (TheSwiftKitWidgets)
│   ├── TheSwiftKitWidgets.swift # widget bundle, timeline provider, views
│   └── Shared/                  # compiled into BOTH app and extension
│       ├── TimerActivityAttributes.swift   # ActivityAttributes for Live Activities
│       └── LiveActivityController.swift    # start/update/end helpers
│
├── Backend/                 # Data layer + server code
│   ├── Protocols/               # Repository protocols + domain models + Local* fallbacks
│   ├── Supabase/                # Supabase repo implementations + setup.sql + edge function
│   └── Python/                  # Flask AI proxy — PRO: OpenAI *or* Gemini + SSE streaming
│
├── Resources/               # Assets.xcassets, Info.plist, Fonts/
│   ├── Base.lproj/              # Localizable.strings (source of truth)
│   └── en.lproj/ es.lproj/ hi.lproj/   # PRO  shipped translations
├── Tests/                   # XCTest unit tests
├── setup.sh                 # Interactive + JSON-driven wizard (also toggles the 13 PRO flags)
├── setup-config.json        # Non-interactive setup input template
└── project.yml              # XcodeGen spec (app target + PRO widget target)
```

---

## 4. Architecture

### The data flow

```
SwiftUI View
   → reads DIContainer from @Environment(\.container)
   → calls a Repository/Service *protocol* (e.g. AuthRepository)
   → concrete impl chosen at startup: Supabase* (live) or Local* (offline)
   → optionally wrapped by a Cached* decorator when featureFlags.enableCaching
```

ViewModels are `@MainActor final class … : ObservableObject` with `@Published`
state. Simple screens read the container directly in the View; heavier screens
use a ViewModel. Follow the pattern that already exists in the neighbouring
module.

### App entry & navigation

`Core/Root/TheSwiftKitApp.swift` (`@main`) builds **one**
`DIContainer.makeDefault()` and one `AppRouter`, injects both, configures
analytics + RevenueCat on launch, and starts the cache sign-out listener when
`enableCaching` is on.

> ⚠️ **PRO footgun.** The `body` contains **two parallel branches** — a
> `#if DEBUG` one that can show `TestDriveView` first, and a `#else` one that
> goes straight to `RootView`. Both carry the same chain of root modifiers:
>
> ```swift
> .inject(container)
> .environmentObject(router)
> .dsTheme(…)
> .preferredColorScheme(…)
> .environment(\.locale, localization.locale)                        // PRO
> .appLockGate(enabled: container.config.featureFlags.biometricLock) // PRO
> .task { … }
> .id(localization.languageCode)                                     // PRO
> ```
>
> **Any root-level modifier you add must be added to BOTH branches**, or it will
> silently work in Debug and vanish in Release (or vice versa).

`Core/Root/RootView.swift` is a `TabView` (Home + Settings). The Home tab holds
a `NavigationStack(path: $router.path)` whose `.navigationDestination` switches
over `AppRoute`. The **paywall** is a `.sheet`; **onboarding** and **auth** are
`.fullScreenCover`s gated by `featureFlags.onboarding` / `featureFlags.auth`.
Subscription/auth state is kept in sync via `NotificationCenter`.

### Routing

`Core/Routing/AppRouter.swift`:

```swift
public enum AppRoute: Hashable {
    case home, settings, detail(id: String), notifications, paywall
    case aiChat, aiImages, aiVision
}
```

> **PRO note — the Pro features are deliberately NOT in `AppRoute`.** They are
> demos, surfaced from `TestDriveView` and `SettingsView` (see
> [6b](#6b-where-pro-features-are-surfaced)). That keeps each one deletable
> without touching the router. If a buyer promotes a Pro feature into their real
> product, *then* add an `AppRoute` case for it.

---

## 4b. Dependency injection (`DIContainer`)

`Core/DI/DIContainer.swift` is a plain `Sendable` **struct** carrying every
service the app needs:

```swift
public struct DIContainer: Sendable {
    public var config: AppConfig
    public var authRepository: AuthRepository
    public var userRepository: UserRepository
    public var profileRepository: ProfileRepository
    public var subscriptionRepository: SubscriptionRepository
    public var purchasesService: PurchasesService
    public var analytics: AnalyticsService
    public var appleSignInService: AppleSignInServiceProtocol
    public var cacheManager: CacheManager
}
```

**This is identical to the base kit — no Pro feature adds a container service.**
That is intentional: a container property would be a compile-time dependency on
a folder the buyer is allowed to delete. Pro features use `@MainActor`
`ObservableObject` singletons instead (see [13c](#13c-pro-managers-and-the-singleton-exception)).

- `DIContainer.makeDefault(config:)` is the composition root. It picks
  `Supabase*` vs `Local*` per `config.backend`, wraps profile/subscription repos
  in `Cached*` decorators when `config.featureFlags.enableCaching`, and selects
  live-vs-noop analytics/purchases based on linked SDKs + present keys.
- Inject with `.inject(container)`; read with
  `@Environment(\.container) private var container`.

**To add a new *core* service:** define a protocol (+ a `Local`/`Noop` fallback),
add a stored property to `DIContainer`, construct it in `makeDefault`, and
consume it from views via the environment.

---

## Feature flags

`Config/FeatureFlags.swift` — **use these exact property names** (the README's
`enableOnboarding`/`enableAuth`/… names are stale).

### Base flags

| Property        | Meaning                                                             |
|-----------------|---------------------------------------------------------------------|
| `onboarding`    | Show the onboarding `fullScreenCover` on first launch               |
| `auth`          | Require authentication; gates the auth cover and profile loading    |
| `paywall`       | React to entitlement changes and present the paywall                |
| `notifications` | Notifications feature enabled                                       |
| `aiFeatures`    | Show the AI section on Home (chat / images / vision)                |
| `appleSignIn`   | Show the "Sign in with Apple" button                                |
| `enableCaching` | Wrap repositories in `Cached*` decorators (default `true`)          |

### PRO flags

| Property                  | Folder it controls              | Meaning                                        |
|---------------------------|---------------------------------|------------------------------------------------|
| `charts`                  | `Modules/Charts`                | Swift Charts demo module                        |
| `reviewPrompt`            | `Modules/Review`                | StoreKit review request + custom pre-prompt     |
| `inAppFeedback`           | `Modules/Feedback`              | Category + message feedback form                |
| `biometricLock`           | `Modules/AppLock`               | Face ID / Touch ID lock (**availability only**) |
| `localization`            | `Modules/Localization`          | Runtime language picker, no restart             |
| `paywallTemplates`        | `Modules/PaywallTemplates`      | 10 paywall templates + gallery                  |
| `widgets`                 | `Widgets/` + widget target      | Home/lock-screen widgets + Live Activities      |
| `questionnaireOnboarding` | `Modules/QuestionnaireOnboarding` | Quiz-style onboarding flow                    |
| `gamification`            | `Modules/Gamification`          | XP, levels, badges, streaks                     |
| `aiPro`                   | `Modules/AIPro`                 | Streaming chat + persisted history              |
| `camera`                  | `Modules/Capture`               | Camera + document scanner + OCR                 |
| `reminders`               | `Modules/Reminders`             | Local reminder scheduling                       |
| `swiftDataStore`          | `Modules/SwiftDataStore`        | SwiftData offline-first store (iOS 17+)         |

**Defaults:** the memberwise init defaults **everything to `false` except
`enableCaching = true`** — including all 13 Pro flags. `setup.sh` rewrites the
`featureFlags:` line in `AppConfig.swift` with the buyer's choices.

> `biometricLock` only makes the feature *available*. The user still opts in via
> the Settings toggle, persisted as the `appLockEnabled` `@AppStorage` key.
> Both must be true for the lock screen to appear.

When you add a flag-gated feature, gate **both** the UI
(`if container.config.featureFlags.x { … }`) and any background work it triggers.

---

## 5. Design system (the "ONE FILE")

Unchanged from the base kit. All theming flows from
**`Core/Theme/DesignSystem.swift`** — the `DS` namespace.

**Tokens you should use instead of literals:**

| Need        | Use                                                                          |
|-------------|------------------------------------------------------------------------------|
| Brand color | `DS.primary`, `DS.accent`                                                     |
| Status      | `DS.success`, `DS.warning`, `DS.danger`, `DS.info`                            |
| Text        | `DS.Colors.textPrimary` / `.textSecondary` / `.textTertiary`                 |
| Surfaces    | `DS.Colors.background` / `.surface` / `.surfaceSecondary`                     |
| Lines       | `DS.Colors.border`, `DS.Colors.divider`                                       |
| Spacing     | `DS.Spacing.xs sm md lg xl xxl xxxl` (scaled by `DS.spacingDensity`)          |
| Radius      | `DS.Radius.none xs sm md lg xl xxl full`                                      |
| Shadow      | `DS.Shadow.sm/.md/.lg/.xl` (`ShadowToken`)                                    |
| Motion      | `DS.Motion.fast/.normal/.slow`, `DS.Motion.spring`                            |
| Border      | `DS.Border.thin/.regular/.thick`                                              |

**Typography** — never call `.font(...)` with a system font. Use `.appFont(_:)`
with an `AppTextStyle` case (`Core/Theme/Typography.swift`): `largeTitle, title,
title2, title3, headline, body, bodyBold, callout, subheadline, footnote,
footnoteSemibold, caption, captionBold, caption2`.

**Surfaces / cards** (`Core/Theme/Glass.swift`, `DSComponents.swift`):

```swift
VStack { … }.dsCard(radius: DS.Radius.lg)         // card using the global SurfaceStyle
VStack { … }.dsCardContent()                       // padded card in one call
TextField("", text: $x).dsInput()                  // styled input
Button("Continue") { }.buttonStyle(DSPrimaryButtonStyle())   // also Secondary/Ghost/Destructive
DSEmptyState(title:systemImage:description:)        // reusable empty state
```

`SurfaceStyle` (`.flat .bordered .elevated .glass .liquidGlass`) is set globally
via `DS.surfaceStyle` and injected as `DSTheme` (`.dsTheme(...)`).
`.liquidGlass` targets iOS 26+ and falls back to `.glass`.

> **PRO — the 10 paywall templates use the same tokens.** They are *not* a
> parallel styling system. `Modules/PaywallTemplates/PaywallComponents.swift`
> holds shared building blocks; each `TemplateNN*.swift` composes them. A
> retheme via `DS` restyles all ten.

---

## 6. Feature modules

Each module is a self-contained folder under `Modules/` following
**View + (optional) ViewModel + (optional) Coordinator**.

- **Coordinators** own a small flow and report back with a closure, e.g.
  `OnboardingCoordinator(style:pages:done:)` and `AuthCoordinator { user in … }`.
- **Onboarding** has 3 interchangeable styles — `.carousel / .highlights /
  .minimal` from `config.onboardingStyle`. **PRO** adds a fourth, independent
  flow: `QuestionnaireOnboardingView` (see [13](#13-pro-features)).
- **Home** (`HomeView`) is a neutral shell. Feature sections use
  `HomeSection(title:items:)`. The AI section is gated by
  `featureFlags.aiFeatures`. **This is the file to extend when adding the
  buyer's primary feature surface** — note it deliberately shows *no* Pro demos.
- **Demo** — `TestDriveView` is the DEBUG-only launcher **and the Pro feature
  hub**. See below.

### 6b. Where Pro features are surfaced

This is the single most important Pro-specific fact, and the thing most likely
to be got wrong:

| Surface                                  | Features reachable from it                                                                                   |
|------------------------------------------|--------------------------------------------------------------------------------------------------------------|
| `Modules/Demo/TestDriveView.swift` **(`#if DEBUG` only)** | charts · paywallTemplates · gamification · reminders · swiftDataStore · camera · aiPro · widgets · questionnaireOnboarding · localization · inAppFeedback · app-lock test |
| `Modules/Settings/SettingsView.swift` **(ships in Release)** | `biometricLock` toggle · `localization` picker · `inAppFeedback` form · `reviewPrompt` button |
| Root modifier in `TheSwiftKitApp`        | `biometricLock` lock overlay (`.appLockGate`) · `localization` (`\.locale` + `.id`)                            |

**Consequence:** in a **Release** build, nine of the thirteen Pro features have
**no entry point at all**. That is by design — they are reference
implementations the buyer wires into their own product, not shipped screens.
**Do not "fix" this by adding them to `HomeView` or `RootView`** unless that is
the explicit task; it would put demo content in every buyer's shipping app.

**Recipe — add a feature screen (base pattern):**
1. Create `Modules/MyFeature/MyFeatureView.swift` (+ ViewModel if it has logic),
   using `DS`/`.appFont`/localization.
2. Add `case myFeature` to `AppRoute` and a destination in `RootView`.
3. Surface it from `HomeView` via a `HomeSection` item (gate behind a flag if
   optional).
4. `xcodegen generate`.

---

## 7. Localization

Every user-visible string is a key in `Resources/Base.lproj/Localizable.strings`.
Naming is dotted-namespace by area: `home.*`, `settings.*`, `auth.*`, `onb.*`,
`notif.*`, `paywall.*`, `ai.*`, `account.*`, `tester.*`, and **PRO** `applock.*`,
`charts.*`, `feedback.*`, `language.*`.

```swift
Text("settings.title")                                   // Text takes a LocalizedStringKey
Label("home.tab", systemImage: "house.fill")
String(localized: "home.welcome")                        // when you need a String
String(localized: "home.welcome.named \(name)")          // interpolated key form used in this repo
```

> **PRO — this repo ships four `.lproj` folders**: `Base`, `en`, `es`, `hi`,
> and `project.yml` declares `CFBundleLocalizations: [en, es, hi]`. When you add
> a key, add it to **`Base.lproj` and all three language files** in the same
> change. A key present only in `Base` will render as the raw key string for a
> user who has switched to Spanish or Hindi.

**Runtime language switching** (`Modules/Localization/LocalizationManager.swift`)
is a `@MainActor` singleton that installs a bundle hook so
`Localizable.strings` lookups resolve against the chosen language without a
restart. `TheSwiftKitApp` pairs it with `.environment(\.locale, …)` (for date and
number formatting) and `.id(localization.languageCode)` (to force a full view
rebuild on change). Supported list lives in `LocalizationManager.supported` —
**to add a language, add its `<code>.lproj/Localizable.strings`, a row in that
array, and the code to `CFBundleLocalizations` in `project.yml`.**

---

## 8. Caching

Unchanged from base. `Core/Cache/` is an actor-based, two-tier (in-memory + a
dedicated `UserDefaults` suite) cache. `CacheManager.shared` conforms to
`CacheStorage`.

- **Keys:** extend the `CacheKeys` enum (`CacheKeys.profile(userId)`,
  `CacheKeys.subscription(userId)` exist).
- **Expiry:** `CacheExpiry` = `.never / .seconds / .minutes / .hours / .days`;
  named defaults in `CacheConfig`.
- **API:** `get<T>(forKey:)`, `set<T>(_:forKey:expiry:)`, `remove(forKey:)`,
  `removeAll()`, `invalidate(matching:)` (wildcard `*`), `contains(key:)`,
  `allKeys()`.
- **Pattern:** wrap a repository with a `Cached*` **decorator** actor; register
  it in `DIContainer.makeDefault` behind `enableCaching`.
- **Sign-out safety:** `CacheInvalidationObserver.shared.startListening()`
  clears everything on `authStatusDidChange` / `userDidSignOut`.

---

## 9. Backend / data layer

### Repository protocols + domain models (`Backend/Protocols/`)

Unchanged from base.

| Protocol                 | Methods                                                                    | Local fallback / Supabase impl                            |
|--------------------------|----------------------------------------------------------------------------|-----------------------------------------------------------|
| `AuthRepository`         | `signIn`, `signUp`→`SignUpOutcome`, `signInWithApple(idToken:nonce:)`, `signOut`, `currentUser` | `LocalAuthRepository` (actor) / `SupabaseAuthRepository`  |
| `UserRepository`         | `fetchCurrentUserProfile() -> User`                                         | `LocalUserRepository`                                     |
| `ProfileRepository`      | `fetchProfile(for:)`, `upsertProfile(_:)`, `uploadAvatar(data:for:contentType:)` | `LocalProfileRepository` / `SupabaseProfileRepository`    |
| `SubscriptionRepository` | `fetch(for:) -> SubscriptionStatus?`                                        | `LocalSubscriptionRepository` (no Supabase impl)          |

**Domain models** (all `Codable, Sendable`): `User{id,email}`,
`Profile{id,name,gender,contact,avatarURL,subscriptionStatus,updatedAt}`,
`Gender{unspecified,male,female,other}`, top-level
`SubscriptionStatus{plan,expiresAt}`, `SubscriptionPlan{free,pro,premium}`,
`SignUpOutcome{signedIn(User),confirmationEmailSent}`.

> There are **two** `SubscriptionStatus` types: nested
> `Profile.SubscriptionStatus` (display string enum) and the top-level struct
> used by `SubscriptionRepository`. Don't conflate them.

### Conditional SDK imports

Third-party SDK usage is always guarded so the project compiles with **zero**
packages linked:

```swift
#if canImport(RevenueCat)
purchases = RevenueCatPurchasesService(apiKey: Secrets.revenueCatAPIKey)
#else
purchases = NoopPurchasesService()   // demo data, logs a warning
#endif
```

Same for Supabase (→ `Local*`) and TelemetryDeck/TelemetryClient
(→ `NoopAnalyticsService`). **Preserve this when touching service code.**

---

## 9b. Core services

- **`AnalyticsService`** — `configure()`, `track(_:properties:)`,
  `identify(userID:)`. Live `TelemetryDeckAnalyticsService` or `Noop`.
- **`PurchasesService`** — `configure`, `logIn`, `logOut`, `restorePurchases`,
  `refreshSubscriptionStatus`, `loadOfferings(includeAll:) -> [PurchaseOption]`,
  `purchase(packageIdentifier:)`, `showManageSubscriptions`.
- **`AppleSignInServiceProtocol`** — `@MainActor authorize() async throws ->
  AppleSignInResult`; pass to `authRepository.signInWithApple(idToken:nonce:)`.
- **`NotificationService.shared`** (`@MainActor`) — authorization, local
  scheduling, pending management, APNs registration + device token.
- **`RatingService`** / **`AccountDeletionService`**.
- **`AppLogger.log(_:level:)`** — DEBUG-only. Use instead of bare `print`.

### App events

`Core/Utils/AppEvents.swift` defines `Notification.Name`s: `.authStatusDidChange`,
`.profileDidChange`, `.subscriptionDidChange`, `.userDidSignOut`.
`subscriptionDidChange` carries `userInfo` keyed by
`SubscriptionEventKey.productName` / `.expiresAt`. Post these when you change the
corresponding state; observe with `.onReceive(NotificationCenter…)`.

---

## 10. Configuration, secrets & the setup wizard

### `Config/AppConfig.swift`

`AppConfig` carries `appName`, `bundleId`, `backend` (`.supabase`/`.local`),
`layout`, `onboardingStyle`, `branding`, `featureFlags`, `legal`.

### `Config/Secrets.swift` (generated, gitignored)

Shape defined by `Config/Secrets.sample.swift`. Keys: `supabaseURL`,
`supabaseAnonKey`, `appleServiceId`/`appleTeamId`/`appleKeyId`/
`applePrivateKeyPEM` (web SIWA only), `accountDeletionURLString`(+`URL`),
`telemetryDeckAppID`, `revenueCatAPIKey`, `aiBackendBaseURLString`(+`URL`).
**Identical to the base kit — Pro adds no new secrets** (the Gemini key lives on
the server, not in the app). **Empty keys are valid** → noop/local fallbacks.

### Setup wizard & placeholders

`./setup.sh` (interactive) or `./setup.sh --config setup-config.json`:

- Replaces tokens repo-wide: `__APP_NAME__`, `__BUNDLE_ID__`,
  `__PRIMARY_COLOR__`, `__ACCENT_COLOR__`, `__PRIVACY_URL__`, `__TERMS_URL__`,
  `__TESTFLIGHT_APP_ID__`.
- Generates `Config/Secrets.swift`.
- Rewrites `AppConfig.swift` (`backend`, `onboardingStyle`, the full
  `featureFlags:` line — **including all 13 Pro flags**) and `DesignSystem.swift`.
- Updates `project.yml` + `project.pbxproj` and runs `xcodegen generate`.

Treat leftover `__…__` tokens as "not yet configured", not as bugs.

---

## 11. AI backend (Flask proxy)

`Backend/Python/app.py` is a standalone Flask server (**not** part of the iOS
target). The Swift side calls it through `Core/Services/AIApiClient.swift` and
**PRO** `Modules/AIPro/AIProStreamClient.swift`, using `Secrets.aiBackendBaseURL`.

> **PRO — this backend is dual-provider.** Set `LLM_PROVIDER=openai` (default)
> or `LLM_PROVIDER=gemini` in `.env`. The **iOS app does not change**; only the
> server does.

| Endpoint            | Method | OpenAI model     | Gemini model                  | Swift caller                          |
|---------------------|--------|------------------|-------------------------------|---------------------------------------|
| `/v1/chat`          | POST   | `gpt-4o`         | `gemini-2.5-flash`            | `AIApiClient.sendChat(...)`           |
| `/v1/chat/stream` **PRO** | POST | `gpt-4o` (SSE) | `gemini-2.5-flash` (SSE)  | `AIProStreamClient.stream(...)`       |
| `/v1/images`        | POST   | `gpt-image-1.5`  | `imagen-3.0-generate-002`     | `AIApiClient.generateImages(...)`     |
| `/v1/vision`        | POST   | `gpt-4o`         | `gemini-2.5-flash`            | `AIApiClient.visionAnalyze(...)`      |
| `/health`           | GET    | —                | —                             | —                                     |

Every model is env-overridable (`OPENAI_CHAT_MODEL`, `GEMINI_CHAT_MODEL`, …);
`OPENAI_BASE_URL` supports proxies/Azure. Image generation on Gemini requires an
SDK version with `ImageGenerationModel` — the server returns a clear error and
suggests `LLM_PROVIDER=openai` otherwise.

Run locally:

```bash
cd Backend/Python
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env      # set LLM_PROVIDER + the matching API key
python app.py             # http://0.0.0.0:5001
```

If you change the request/response JSON on either side, **change both**
`app.py` and the Swift `Codable` structs together (`ChatReply { reply }`,
`ImagesResponse { images: [String] }` base64, `VisionResponse { result }`).

> **AIPro degrades gracefully.** `AIProStreamClient` falls back to a built-in
> canned streamer when `/v1/chat/stream` is unreachable, so the chat demo always
> streams even with no backend running. Don't remove that fallback — it is what
> makes the feature demo-able out of the box.

---

## 12. Conventions cheat-sheet

- **Concurrency:** repositories and the cache are `actor`s; ViewModels,
  UI-touching services and **all Pro managers** are `@MainActor`. Keep new
  shared mutable state inside an actor and mark cross-boundary types `Sendable`.
- **No singletons for app services** — go through `DIContainer`. Framework-y
  shared objects (`CacheManager.shared`, `NotificationService.shared`) and **Pro
  managers** are the deliberate exceptions; see [13c](#13c-pro-managers-and-the-singleton-exception).
- **Previews:** keep `PreviewProvider`s working; they rely on the default
  container + local fallbacks, so don't make views require live keys.
- **SF Symbols** for icons; brand/asset images via `Assets.xcassets`.
- **Match the neighbours.** Before adding a file, open the closest existing
  module and mirror its structure, naming, and comment density.

---

## 13. PRO features

Thirteen features, each in its own folder, each behind its own flag.

| Feature | Folder | Flag | Notes |
|---|---|---|---|
| AI PRO — streaming chat | `Modules/AIPro` | `aiPro` | `AIProStreamClient` (SSE) + `AIChatStore` (persisted history) + `AIProChatView`. Offline mock streamer fallback. |
| Widgets + Live Activities | `Widgets/` | `widgets` | Separate `TheSwiftKitWidgets` extension target, iOS 16.1+. `Widgets/Shared` compiles into both app and extension. |
| Gamification | `Modules/Gamification` | `gamification` | `GamificationEngine.shared` — XP, levels, badges, streaks. |
| Quiz onboarding | `Modules/QuestionnaireOnboarding` | `questionnaireOnboarding` | Independent of the 3 base onboarding styles. |
| Camera + OCR | `Modules/Capture` | `camera` | `DocumentScannerView` (VisionKit) + `TextRecognizer` (Vision). Needs `NSCameraUsageDescription`. |
| Reminders | `Modules/Reminders` | `reminders` | `ReminderScheduler.shared` on top of `NotificationService`. |
| SwiftData store | `Modules/SwiftDataStore` | `swiftDataStore` | **`@available(iOS 17, *)`** — the project ships iOS 16, so every entry point is availability-gated. |
| 10 paywall templates | `Modules/PaywallTemplates` | `paywallTemplates` | `Template01…Template10` + `PaywallGalleryView` + shared `PaywallComponents`. Uses `DS` tokens. |
| Swift Charts | `Modules/Charts` | `charts` | Swift Charts is iOS 16+, so no availability gate needed. |
| In-app feedback | `Modules/Feedback` | `inAppFeedback` | Form + `FeedbackService`. Reachable in Release via Settings. |
| Biometric app lock | `Modules/AppLock` | `biometricLock` | `AppLockManager.shared` + `.appLockGate()` root modifier. Needs `NSFaceIDUsageDescription`. Requires the Settings opt-in too. |
| Runtime localization | `Modules/Localization` | `localization` | `LocalizationManager.shared`, en/es/hi. Reachable in Release via Settings. |
| Review prompt | `Modules/Review` | `reviewPrompt` | `ReviewManager.shared` — native StoreKit request + pre-prompt. Reachable in Release via Settings. |

### The removal contract

Every Pro feature must stay removable in **two steps**:

1. Flip its flag to `false` in `AppConfig.default` (or via `setup.sh`).
2. Delete its folder.

For that to hold, **nothing outside a feature's folder may reference its types**,
with these audited exceptions, which are the *only* places Pro features touch
shared files:

- `Config/FeatureFlags.swift` — the flag itself.
- `Modules/Settings/SettingsView.swift` — the four Release-reachable features.
- `Modules/Demo/TestDriveView.swift` — the DEBUG hub.
- `Core/Root/TheSwiftKitApp.swift` — `.appLockGate`, `\.locale`, `.id(...)`.
- `project.yml` — widget target, `Widgets/Shared` app source, Info.plist keys.
- `Resources/*.lproj/Localizable.strings` — the feature's keys.

**When you add to or modify a Pro feature, re-check this list.** If your change
makes a shared file depend on a Pro type in a way that would not compile after
deleting the folder, wrap it or move it. This is the property that justifies the
Pro tier's price — a buyer who wants three of the thirteen must not inherit the
other ten.

### 13c. Pro managers and the singleton exception

Base rule: *no singletons for app services, use `DIContainer`.* Pro features
deliberately break it:

```
AppLockManager.shared      LocalizationManager.shared   ReviewManager.shared
GamificationEngine.shared  ReminderScheduler.shared
```

All are `@MainActor final class … : ObservableObject`. The reason is the removal
contract: a `DIContainer` property referencing a Pro type would stop the project
compiling the moment a buyer deleted that folder. A `.shared` singleton inside
the folder disappears cleanly with it.

**Follow this pattern for new Pro features. Do not add Pro services to
`DIContainer`.** For non-Pro core services, the base rule still applies.

---

## 14. PRO-specific footguns

1. **Two `#if DEBUG` branches in `TheSwiftKitApp`.** Root modifiers must be
   added to both. See [4](#app-entry--navigation).
2. **Nine Pro features are DEBUG-only.** `TestDriveView` is their sole entry
   point. Not a bug; don't "fix" it.
3. **Four `.lproj` folders.** A new key needs `Base` + `en` + `es` + `hi`.
4. **`Widgets/Shared` is dual-target.** Anything you put there compiles into the
   app *and* the extension — keep it free of app-only dependencies.
5. **Widget deployment target is 16.1**, higher than the app's 16.0 (Live
   Activities requirement).
6. **SwiftData is iOS 17+** in an iOS 16 project — keep `@available(iOS 17, *)`
   on every entry point you add.
7. **Widgets currently render sample data.** Sharing real data needs an App
   Group, which is *not* configured (no entitlement, no suite name) — there is a
   TODO comment in `Widgets/TheSwiftKitWidgets.swift`. Adding one means a new
   entitlement on both targets plus a `UserDefaults(suiteName:)`.
8. **`biometricLock` is two-condition:** the flag *and* the user's
   `appLockEnabled` toggle.
9. **`setup.sh` writes the whole `featureFlags:` line.** If you add a flag, add
   it to `setup.sh` too or the wizard will silently drop it.
10. **The widget bundle id is intentionally not a placeholder.** `project.yml`
    ships literal `com.agaganorg.theswiftkit` / `…​.widgets`, and `setup.sh`
    rewrites both with one global substring replace, so the extension stays
    prefixed by the host app's id (an App Store requirement). Don't convert
    these to `__BUNDLE_ID__` tokens.

When in doubt, grep the repo for an existing example of what you're about to do
and follow it — this template is internally consistent, and consistency is more
valuable here than personal preference.
