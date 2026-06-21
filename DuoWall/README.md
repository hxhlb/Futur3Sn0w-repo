# DuoWall

DuoWall creates a custom appearance-aware still wallpaper on jailbroken iOS 15 and 16 devices. Choose one light image and one dark image in the DuoWall preference pane, then apply the pair directly or select **DuoWall** from the native wallpaper picker. iOS handles later appearance changes itself.

The implementation uses WallpaperKit's native appearance-aware bundle behavior instead of repeatedly replacing SpringBoard wallpaper files. Version 0.0.4 adds iOS 16's `WKWallpaperRepresentingCollectionsManager` and a direct apply path through `WKSystemShellWallpaperManager`.

If applying or collection loading fails, retrieve these files with Filza:

- `/var/mobile/Documents/DuoWall-Preferences-method-dump.txt`
- `/var/mobile/Documents/DuoWall-PosterBoard-method-dump.txt`
- `/var/mobile/Documents/DuoWall-backend-log.txt`

## Build

```sh
env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache make clean package
```

## Credits and license

The WallpaperKit bundle-injection approach is based on Skitty's GPL-3.0 WallpaperLoader project. DuoWall is therefore distributed under GPL-3.0; see `LICENSE`.
