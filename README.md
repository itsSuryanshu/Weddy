# PupWeather

A pixel-art golden retriever that lives on your Lock Screen. Its world — sky,
sun, moon, stars, clouds, hills, trees, grass, rain, snow, fog, butterflies,
flowers — mirrors the live weather at your location via an iOS Live Activity.

## How the scene is drawn

There are no images and no fonts. Every element is a code-defined model:

- **Sprites** (`Shared/PupSprites.swift`) — the dog's five poses (sit, trot,
  sniff, jump, sleep), trees, clouds, sun, moon, butterflies, lightning,
  flowers are character grids with per-sprite palettes. Edit the strings to
  edit the art.
- **Engine** (`Shared/PixelArt.swift`) — sprites and procedural layers
  rasterize into a handful of merged vector `Path`s (one per color), the one
  rendering primitive Live Activities support without restriction. A seeded
  SplitMix64 RNG keeps the app and the widget extension pixel-identical.
- **Composer** (`Shared/PupSceneView.swift`) — assembles banded sky, celestial
  bodies, rolling hills, tree line, field, foreground grass, weather particles
  and the dog for each `PupScene`, styled per scene (vibrant day greens, snowy
  whites, stormy darks…).

## How the dog moves

Live Activities can't run timers or animation loops, so movement is driven by
content-state updates. `SceneLayout` (dog position, facing, action, world
seed) travels inside the activity's content state:

- While the app is frontmost, `LiveActivityManager` pushes a wander update
  every ~2 minutes — the dog slides to a new random spot and picks a new
  scene-appropriate action.
- While backgrounded, each `BGAppRefreshTask` weather refresh doubles as a
  wander tick (iOS schedules these roughly every 15–30 minutes).
- The world seed stays fixed across updates, so trees, clouds and stars stay
  put while the dog roams.

| Scene | Dog behavior |
|---|---|
| clearDay | trots around, sits, sniffs the flowers |
| warmDay (clear and ≥ 20 °C) | jumps around with the butterflies |
| cloudy | sits, trots, watches the clouds |
| rain / thunder | sits in the rain (+ lightning) |
| snow | hops and trots through the snowfall |
| fog | sniffs through the mist |
| night | curled up asleep under moon and stars, Zzz |

Weather comes from [Open-Meteo](https://open-meteo.com) (free, no API key) via
a one-shot CoreLocation fix.

## Project layout

- `App/` — SwiftUI app: home screen with live scene preview + scene browser,
  location + weather services, Live Activity manager, background refresh
- `PupWidget/` — widget extension: Lock Screen Live Activity
- `Shared/` — compiled into both targets: pixel engine, sprites, scene
  composer, scene model, `ActivityAttributes`
- `tools/render_scenes.swift` — renders every scene and dog pose to
  `tools/out/*.png` for reviewing art changes without a simulator

## Build

```sh
brew install xcodegen
xcodegen generate
open PupWeather.xcodeproj
```

Set your signing team on both targets, then run the `PupWeather` scheme on an
iOS 17+ device or simulator. Grant location access when prompted and lock the
screen. Opening the app automatically restores the Lock Screen Live Activity
if you swipe it away.

Note: background refresh budgets only behave realistically on a physical
device.

## Previewing the art

```sh
swiftc -parse-as-library -D RENDER_TOOL \
    tools/render_scenes.swift Shared/PixelArt.swift Shared/PupSprites.swift \
    Shared/PupScene.swift Shared/SceneLayout.swift Shared/PupSceneView.swift \
    -o /tmp/render_scenes && /tmp/render_scenes
open tools/out
```

There is also an Xcode preview in `PupSceneView.swift` showing all eight
scenes, and the in-app scene browser lets you flip through them live.
