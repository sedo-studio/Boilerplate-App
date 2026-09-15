# Monetization setup

Two products, sold independently. They are never shown together as tiers — each
is offered at the moment it makes sense.

| | Radar unlock | Left-behind alerts |
|---|---|---|
| Entitlement id | `radar_unlock` | `left_behind_alerts` |
| Offering id | `radar_unlock` | `left_behind_alerts` |
| Product type | Non-consumable | Auto-renewing subscription |
| Price | $9.99 | $4.99 / month |
| Unlocks | The radar/proximity screen, permanently | Proactive disconnect notifications |
| Offered | Straight after the free "Found nearby" moment | From Settings, and as a soft prompt after a successful find |

The identifiers are defined once in `AppEntitlement`
(`Core/Services/PurchasesService.swift`) and asserted in `ContainerTests`. If
you rename anything in RevenueCat, change it in both places — a mismatch locks
paying customers out of what they bought, silently.

## App Store Connect

1. Create the in-app purchases:
   - **Non-consumable**, e.g. `com.yourcompany.findmyheadphones.radar` at $9.99.
   - **Auto-renewable subscription** in a new group, e.g.
     `com.yourcompany.findmyheadphones.alerts.monthly` at $4.99/month.
2. Fill in review notes explaining that the radar is a one-time unlock and the
   subscription is a separate, ongoing feature. Reviewers reject paywalls whose
   terms are unclear.
3. Attach the subscription's terms: price, period, and that it renews until
   cancelled. The app shows this in `paywall.alerts.footnote`.

## RevenueCat

1. Create two **entitlements**: `radar_unlock` and `left_behind_alerts`.
2. Attach each App Store product to its entitlement.
3. Create two **offerings**, named `radar_unlock` and `left_behind_alerts`, each
   containing only its own product. The app requests an offering by entitlement
   name, which is what keeps the two paywalls from showing each other's prices.
   (If an offering is missing, the app falls back to the current offering rather
   than showing an empty paywall — useful in development, wrong in production.)
4. Put the public SDK key in `Config/Secrets.swift` (via `./setup.sh`).

## Without RevenueCat

If the SDK is unlinked or the key is empty, `LocalPurchasesService` takes over:

- **Debug builds** grant purchases locally so the whole flow can be walked in
  the simulator. Clear them with `resetLocalPurchases()`.
- **Release builds** grant nothing. A shipped app with a missing key sells
  nothing rather than giving everything away.

## Testing the flow

1. Fresh install → onboarding → scan → "Found nearby".
2. Tap "Show me how close" → paywall #1 appears → purchase → the radar opens
   automatically on dismiss.
3. Confirm a find twice → the alerts soft prompt appears (first find is too
   early; `LeftBehindPromptPolicy` enforces that, and a 14-day cooldown after a
   decline).
4. Settings → restore purchases → both entitlements come back.
5. Let the subscription lapse in a sandbox account → alerts stop arming on the
   next foreground, without the user doing anything.

## The funnel

Tracked in TelemetryDeck via `AnalyticsEvent`:

- `Finder.Scan.Started` → `Finder.Scan.Found` / `Finder.Scan.Empty` — detection
  success rate.
- `Paywall.Radar.Viewed` → `Paywall.Radar.Purchased` — unlock conversion.
- `Paywall.Alerts.Viewed` → `Paywall.Alerts.Purchased` — subscription
  conversion, kept separate from the unlock.
- `Finder.Find.Succeeded` — the moment worth tying a review prompt to.
