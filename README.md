# Futur3Sn0w's Public Repo

Source for Futur3Sn0w jailbreak tweaks and related package-repo files.

## Tweaks

| Tweak | Package | Status | Summary |
| --- | --- | --- | --- |
| BattFX | `com.futur3sn0w.battfx` | Rootless public source | Styles the system battery indicator while keeping the modern percentage body available systemwide. |
| BatteryMirror | `com.futur3sn0w.batterymirror` | Rootless public source | Mirrors the status bar battery indicator on the Low Power Mode toggle in Control Center. |
| CCSupport Battery Fix | `com.futur3sn0w.ccsupportbatteryfix` | Rootless public source | Companion patch for CCSupport that fixes status bar battery percentage display on iOS 15+. |
| CenterLastRow | `com.futur3sn0w.centerlastrow` | Early public source | Centers the final SpringBoard icon row when it is not full. |
| CustHome | `com.futur3sn0w.custhome` | Rootless public source | Backports the modern Home Screen customize experience to iOS 15, 16, and 17. |
| DockFull | `com.futur3sn0w.dockfull` | Rootless public source | Extends the modern dock background to the screen edges and removes the rounded corners. |
| DockLibrary | `com.futur3sn0w.docklibrary` | Rootless public source | Swipe up from the dock to open the App Library. |
| DuoWall | `com.futur3sn0w.duowall` | Rootless public beta | Creates named light/dark wallpaper pairs that appear in Collections and follow system appearance on iOS 15 and 16. |
| Finn | `com.futur3sn0w.finn` | Rootless public source | Tints the homescreen context-menu backdrop to the app icon color. Rootless rewrite of Koi for iOS 15 & 16. |
| MuteFlash | `com.futur3sn0w.muteflash` | Rootless public source | Toggles the flashlight when flipping the ringer switch on devices without the Action button. |
| MuteModule | `com.futur3sn0w.mutemodule` | Rootless public source | Exposes Apple's hidden Silent Mode Control Center module on iPhone. |
| NoSeparators | `com.futur3sn0w.noseparators` | Early public source | Hides common UIKit separator lines systemwide on iOS 11. |
| ReRoadRunner | `com.futur3sn0w.reroadrunner` | Rootless public source | Keeps the now-playing app alive through resprings so music and audio continue uninterrupted. iOS 16 rootless (Dopamine) rebuild of Nosskirneh's RoadRunner. |
| Solert | `com.futur3sn0w.solert` | Rootless public source | Restyles `UIAlertController` with an iOS 26-inspired look on iOS 15+. |
| SwipeForMore | `com.futur3sn0w.swipeformore7` | iOS 7 compatibility fork | Brings SwipeForMore-style Cydia package actions to older iOS targets. |
| TapTimeNeo | `com.futur3sn0w.taptimeneo` | Rootless public source | Tapping the status bar clock toggles it to the current date on iOS 15+. |

## Building

Each tweak is a Theos project. From a tweak folder:

```sh
make package
```

If device SSH defaults are configured:

```sh
make install
make do
```

## Notes

`SwipeForMore7` is an iOS 7 compatibility fork of PoomSmart's MIT-licensed SwipeForMore project. The original license is preserved in `SwipeForMore/LICENSE`.
