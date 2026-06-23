# DuoWall

DuoWall creates custom appearance-aware still wallpapers on jailbroken iOS 15 and 16 devices. Pick one light image and one dark image in the DuoWall preference pane, give the pair a friendly name, and DuoWall adds it to the native wallpaper picker under Collections. Once selected there, iOS handles later light/dark appearance changes on its own.

The tweak now focuses on the native Collections flow instead of repeatedly replacing SpringBoard wallpaper files. Each DuoWall is saved as its own WallpaperKit-backed bundle with a friendly name, light/dark previews in prefs, and a small management UI for reviewing or deleting previously added pairs.

Current flow:

- Choose a light appearance image
- Choose a dark appearance image
- Tap **Name & Apply DuoWall**
- Enter the friendly name you want shown in Collections
- Open the wallpaper picker and select the new DuoWall from Collections

If you are debugging a problem, DuoWall still writes `/var/mobile/Documents/DuoWall-backend-log.txt` and can generate compatibility dumps when the underlying helper is called manually.

## Build

```sh
env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache make clean package
```

## Credits and license

The WallpaperKit bundle-injection approach is based on Skitty's GPL-3.0 WallpaperLoader project. DuoWall is therefore distributed under GPL-3.0; see `LICENSE`.
