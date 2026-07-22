# Futur3Sn0w's Public Repo

This repository is now the public package feed and webpage source for Futur3Sn0w jailbreak tweaks.

User-facing repo URL:

```text
https://futur3sn0w.github.io/repo/
```

Public tweak source has moved to the MoarTweaks organization so each package can be developed and released independently.

## Source Repositories

| Tweak | Package | Source |
| --- | --- | --- |
| BattFX | `com.futur3sn0w.battfx` | https://github.com/MoarTweaks/Batt27 |
| BatteryMirror | `com.futur3sn0w.batterymirror` | https://github.com/MoarTweaks/BatteryMirror |
| CCSupport Battery Fix | `com.futur3sn0w.ccsupportbatteryfix` | https://github.com/MoarTweaks/CCSupportBatteryFix |
| CenterLastRow | `com.futur3sn0w.centerlastrow` | https://github.com/MoarTweaks/CenterLastRow |
| CustHome | `com.futur3sn0w.custhome` | https://github.com/MoarTweaks/CustHome |
| DockFull | `com.futur3sn0w.dockfull` | https://github.com/MoarTweaks/DockFull |
| DockLibrary | `com.futur3sn0w.docklibrary` | https://github.com/MoarTweaks/DockLibrary |
| DuoWall | `com.futur3sn0w.duowall` | https://github.com/MoarTweaks/DuoWall |
| Finn | `com.futur3sn0w.finn` | https://github.com/MoarTweaks/Finn |
| MuteFlash | `com.futur3sn0w.muteflash` | https://github.com/MoarTweaks/MuteFlash |
| MuteModule | `com.futur3sn0w.mutemodule` | https://github.com/MoarTweaks/MuteModule |
| NoSeparators | `com.futur3sn0w.noseparators` | https://github.com/MoarTweaks/NoSeparators |
| Solert | `com.futur3sn0w.solert` | https://github.com/MoarTweaks/Solert |
| SwipeForMore7 | `com.futur3sn0w.swipeformore7` | https://github.com/MoarTweaks/SwipeForMore |
| TapTimeNeo | `com.futur3sn0w.taptimeneo` | https://github.com/MoarTweaks/TapTimeNeo |

## Feed Maintenance

The package feed still lives here so existing users do not need to change repo URLs.

Feed metadata lives in `repo/package-sources.tsv`. Built `.deb` files can come from this repository or external source checkouts by setting `MOARTWEAKS_DEB_SEARCH_ROOTS` to a colon-separated list of search roots before running:

```sh
scripts/publish-package-repo.sh --push
```

## Notes

`SwipeForMore7` is an iOS 7 compatibility fork of PoomSmart's MIT-licensed SwipeForMore project. The original license is preserved in the source repository.
