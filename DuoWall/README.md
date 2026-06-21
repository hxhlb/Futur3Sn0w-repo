# DuoWall

DuoWall creates a custom appearance-aware still wallpaper on jailbroken iOS 15 devices. Choose one light image and one dark image in the DuoWall preference pane, then select **DuoWall** once from the native wallpaper picker. iOS handles later appearance changes itself.

The initial implementation intentionally uses WallpaperKit's native appearance-aware bundle behavior instead of repeatedly replacing SpringBoard wallpaper files.

## Build

```sh
env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache make clean package
```

## Credits and license

The WallpaperKit bundle-injection approach is based on Skitty's GPL-3.0 WallpaperLoader project. DuoWall is therefore distributed under GPL-3.0; see `LICENSE`.
