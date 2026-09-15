# App Store listing notes

## Naming

**Do not put "AirPods" in the app name or subtitle.** It is an Apple trademark;
using it in your title invites rejection and a dispute you cannot win. The
established apps in this category mostly avoid it in their titles too.

- **Name:** "Find My Headphones" (or a close variant that reads naturally).
- **Subtitle:** describe the mechanism without the trademark, e.g.
  *"Bluetooth finder for lost earbuds"*.
- **Keywords field** (100 characters, hidden from users) is where the search
  intent goes: `airpods,find my headphones,lost airpods,earbuds,bluetooth
  finder,headphone tracker,lost earbuds`. Comma-separated, no spaces after
  commas, no repeats of words already in the name or subtitle.
- **Skip "nearpod"** — it is an unrelated education product and the traffic will
  never convert.

## Description

Lead with the honest promise, because the category's main complaint is
over-promising:

> Find My Headphones tells you whether your headphones are within Bluetooth
> range, then helps you narrow down where with a live warmer/colder signal.

State the limitation in the description itself, above the fold if possible:
headphones have no ultra-wideband chip, so no app — including Apple's own Find
My — can point an arrow at them. Saying this up front converts worse on the
click and much better on the refund and review rate.

Do not claim: direction, compass, bearing, metres, GPS location of the
headphones, or that it works when they are off or out of battery.

## Screenshots

1. The "Found nearby" confirmation — the free moment that proves the app works.
2. The radar with "Getting warmer".
3. The left-behind notification.
4. A plain-text panel stating what it can and cannot do.

Build screenshots with `featureFlags.radarUnlock = false` so the radar is
reachable without a purchase.

## Review notes

Tell the reviewer plainly:

- The app needs Bluetooth and a real accessory; it does nothing in the
  simulator.
- `bluetooth-central` background mode is used to receive connect/disconnect
  events for the left-behind alerts feature, which is the subscription.
- The radar is a one-time non-consumable; the alerts are a separate
  subscription. Neither gates the free detection feature.

## Positioning

The incumbents are cluttered, ad-heavy, and imply precision they do not have.
The wedge is: fewer screens, faster first value (a free "found nearby" within
seconds of opening), and copy that respects the user. Protect that — every new
screen and every new upsell spends the advantage.
