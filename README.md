# 🐣 BabyPlus

BabyPlus is an iOS/watchOS app for keeping track of your baby's sleep, feedings, diaper changes and more — so nobody has to answer _"how many times did the baby pee today? Was it 5 or 6?"_ from memory.

## ✨ What's in the app

**Log in one touch.** The home screen is a grid of quick-log tiles. Tap one for the details sheet; touch and hold it and the entry is written immediately with your last-used values — with an Undo pill, so the shortcut is safe to try. Nursing and naps start a live timer instead, which keeps running while the phone is locked and is restored if the app is relaunched.

**A journal you can read.** Every entry in plain language, on a timeline grouped by day.

**A profile per child.** Every event belongs to exactly one baby, so twins — or a nanny's charges — keep entirely separate logs. Switching is a tap on the hero card, and the choice is remembered by a stable `UUID` rather than an `NSManagedObjectID`, so it survives iCloud sync to another device. The watch asks which baby it is logging for when there is more than one, instead of guessing.

**Insights.** Swift Charts over feeding, sleep, diaper and bottle-volume data, with averages and a week-over-week trend.

**Built on Liquid Glass.** Cards, bars, sheets and buttons use the system's `glassEffect` on iOS 26, grouped into `GlassEffectContainer`s so neighbouring surfaces morph rather than cross-fade. On earlier releases the same views fall back to materials, so layout and behaviour are identical and only the finish changes. Everything honours Dark Mode, Dynamic Type and Reduce Motion.

**Onboarding that shows the real thing.** Five short pages, each pairing a sentence with a *live rendering of the actual control* it describes — the same `QuickLogTileContent`, `TimelineRowContent`, `BabyHeroCardContent`, `LiveSessionCapsule` and `FeedsChart` the app uses, fed with sample data. The quick-log page animates the touch-and-hold gesture on a loop so the shortcut is learned before it's needed. Nothing is a static screenshot, so the walkthrough can't go stale, and it renders in the user's own appearance and text size.

## 💳 BabyPlus+ (subscription)

A monthly or yearly auto-renewing subscription, implemented with StoreKit 2 in [`MabyKit/Sources/MabyKit/Subscription`](MabyKit/Sources/MabyKit/Subscription).

| | Free | BabyPlus+ |
|---|---|---|
| Logging (all event types, timers, undo) | ✅ | ✅ |
| iCloud sync + Apple Watch | ✅ | ✅ |
| Baby profiles | 1 | Unlimited |
| Journal history | Last 7 days | Everything |
| Insights & trends | — | ✅ |
| CSV export | — | ✅ |
| Smart reminders | — | ✅ |
| Themes & accents | — | ✅ |

`SubscriptionService` treats StoreKit as the only source of truth: entitlement comes from `Transaction.currentEntitlements` on launch and on every foreground, and `Transaction.updates` keeps it correct while the app runs, so refunds, expiry, Family Sharing and purchases made on another device all work without extra code. Nothing about subscription state is cached anywhere it could go stale.

Locked screens show your *own* data behind frosted glass rather than a blank wall (`PremiumGate`), and the paywall puts price, cadence and renewal terms on screen above the button.

### Product identifiers

| Product | Identifier |
|---|---|
| Monthly | `com.elbeheiry.babyplus.pro.monthly` |
| Yearly | `com.elbeheiry.babyplus.pro.yearly` |

Both live in the `babyplus_pro` subscription group.

### Testing purchases locally

[`BabyPlus.storekit`](BabyPlus.storekit) mirrors the App Store Connect setup and is already wired into the shared scheme, so purchases, trials and restores work in the simulator with no App Store Connect account. To exercise the Pro UI without going through a purchase at all, enable the `-BabyPlusForcePro YES` launch argument in the scheme (it is present but disabled, and is compiled out of release builds).

## ⚙️ Building

Requires **Xcode 26** (iOS 26 SDK) — the Liquid Glass APIs are behind `#available(iOS 26, *)` checks, but they still need the 26 SDK to compile. Deployment targets are iOS 18 and watchOS 11.

```bash
git clone https://github.com/h-elbeheiry/babyplus/
open BabyPlus.xcodeproj
```

### ❗️ CloudKit

The app uses CloudKit to sync, so a **paid** developer account is needed. To build locally without it, remove the iCloud capability from the BabyPlus target and change `NSPersistentCloudKitContainer` to `NSPersistentContainer` in [`MabyKit/Sources/MabyKit/Persistence.swift`](MabyKit/Sources/MabyKit/Persistence.swift).

> With CloudKit disabled the watchOS companion won't see the phone's data — it talks to the iOS database through CloudKit, so it will quietly create its own local store instead.

## 🧱 Project layout

```
Maby/
  Design/        Palette, Liquid Glass wrappers, motion tokens, haptics, shared components
  Home/          Today screen, quick-log tiles, hero card, live session capsule
  Journal/       Timeline
  Insights/      Charts and the premium analytics tab
  Onboarding/    Walkthrough + the live UI showcases
  Paywall/       Paywall, presenter, premium gating
  Events/        Add-event sheets
  Settings/      Baby details, subscription, appearance, reminders, export
MabyKit/         Core Data model, services, StoreKit, statistics, export, reminders
```

`Maby/Design/LiquidGlass.swift` is the single place that knows about `glassEffect`, `GlassEffectContainer`, `glassEffectID`, the glass button styles, `tabBarMinimizeBehavior`, `scrollEdgeEffectStyle` and `backgroundExtensionEffect`, each with an availability check and a material fallback. Nothing else in the app touches those APIs directly.

## ⬇️ Where can I get it?

[<img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg">](https://apps.apple.com/us/app/maby-baby-tracker/id1635144505)

## 😀 Contributions/feedback

Feel free to submit ideas or feedback through the issues here on GitHub. Before opening a PR, please open an issue first so we can discuss the approach and whether it's a feature we want.
