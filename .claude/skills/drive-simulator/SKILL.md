---
name: drive-simulator
description: Drive the TestU app in the iOS Simulator by tapping UI elements — use when asked to demo, drive, or interactively verify the app on the simulator.
---

# Drive the iOS Simulator

There is no API to tap inside the Simulator. The recipe: screenshot the
device, locate the target in device points, convert to Mac screen
coordinates, click with `cliclick`, verify with another screenshot.

## Setup

1. Run the app (or reuse a live shell): `flutter run -t lib/main_testu.dart`
   on the iPhone 17 Pro simulator.
2. `cliclick` must be installed (`brew install cliclick`) and the terminal
   needs Accessibility permission. The Mac must stay unlocked — clicks stop
   landing on the lock screen (a black `screencapture` is the tell).

## Coordinates

- `xcrun simctl io booted screenshot /tmp/shot.png` captures in **device
  pixels**. iPhone 17 Pro is @3x: divide by 3 for logical points
  (402×874 pt screen).
- The Simulator window position/size on the Mac desktop is arbitrary. Get it:
  `osascript -e 'tell app "System Events" to get {position, size} of window 1 of process "Simulator"'`

## Calibrate (redo whenever the window moves or resizes)

Derive a linear map `mac = (origin + scale·pt) · displayScale` from two
landmarks visible in both the device screenshot and a Mac `screencapture`:

- status-bar clock: device pt (73, 32)
- TODAY tab icon: device pt (50, 819)

Two anchors give scale and origin per axis. On a Retina Mac, `screencapture`
output is 2x — account for the display scale factor when reading Mac pixels.

## Drive loop

For every step: screenshot → find target pt → map → `cliclick c:X,Y` →
screenshot again to confirm the UI actually changed before the next tap.
Never chain taps blind; a single mis-click can pop a route.

## Cleanup

`flutter run` rewrites `ios/Runner.xcodeproj/project.pbxproj` to
objectVersion 54. Per CLAUDE.md it must stay 60: if that's the only diff,
`git checkout -- ios/Runner.xcodeproj/project.pbxproj` before committing.
