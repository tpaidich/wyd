# Wyd - What're You Drinking?

A hydration tracker for iOS. It sets your daily goal from your body and the
weather, counts the bottle you already sip from, and credits each drink for
what it actually contributes.

## How the goal works

- **Body baseline** from weight, age, sex and activity level.
- **Heat allowance** on top, driven by the *heat index* rather than the
  thermometer. Humid air blocks evaporative cooling, so a 91°F day at 65%
  humidity works the body like 104°F. Weather comes from Open-Meteo, which
  needs no API key.

## How drinks count

Most drinks scale with volume: milk counts for more than water (its protein and
electrolytes slow gastric emptying, so more fluid is retained), soda counts for
less. Alcohol is different - its diuretic cost tracks the alcohol rather than
the liquid, so a spirit goes backwards while a beer still nets out positive.

These are rough guides, not medical advice.

## Building

The Xcode project is generated from `project.yml`, so it is not committed.

```
brew install xcodegen
xcodegen generate
open WaterTracker.xcodeproj
```

Requires iOS 17 or later.

## Running it on a phone

```
./scripts/install-on-phone.sh
```

Plug the phone in and unlock it first. The script finds the device, builds,
signs and installs.

A free Apple ID signs apps for seven days, so Wyd stops opening after a week.
The app is never removed and neither is anything you logged, since the history
lives in the app's own database; only the signature expires. Run the script
again to renew it. The Apple Developer Program lifts this to a year, and brings
TestFlight with it, which is the only practical way onto someone else's phone.

`project.yml` carries a `DEVELOPMENT_TEAM`. Building on another machine means
replacing it with that machine's own team.
