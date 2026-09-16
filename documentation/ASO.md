# App Store listing notes

## Naming

**Do not put "AirPods" in the app name or subtitle.** It is an Apple trademark;
using it in your title invites rejection and a dispute you cannot win. The
established apps in this category mostly avoid it in their titles too.

**"Find My" is also Apple's trademark**, and "Find My Headphones" was taken on
the App Store anyway. Both point the same way: lead with the noun people search
for, not with Apple's verb.

- **Name:** **Headphone Finder** (registered, App Store id `6812735564`). An
  exact match for the highest-intent generic search in the category.
- **Subtitle:** a separate 30 characters, indexed alongside the name. Spend it
  on words the name does not already have, e.g.
  *"Find lost earbuds by signal"*.
- **Keywords field** (100 characters, hidden from users) is where the trademark
  goes, never the name: `airpods,lost,bluetooth,locate,tracker,buds,missing,
  pods,signal,nearby`. Comma-separated, no spaces after commas, and **no word
  already used in the name or subtitle** — Apple indexes all three together, so
  a repeat is a wasted character.
- **Home-screen name** is `CFBundleDisplayName` in `project.yml`, set to
  "Headphones". It is deliberately shorter than the App Store name because home
  screens truncate around twelve characters.
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
