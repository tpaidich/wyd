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
