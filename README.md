# Futur3Sn0w's Public Repo

Source for Futur3Sn0w jailbreak tweaks and related package-repo files.

## Tweaks

| Tweak | Package | Status | Summary |
| --- | --- | --- | --- |
| CenterLastRow | `com.futur3sn0w.centerlastrow` | Early public source | Centers the final SpringBoard icon row when it is not full. |
| NoSeparators | `com.futur3sn0w.noseparators` | Early public source | Hides common UIKit separator lines systemwide on iOS 11. |
| Solert | `com.futur3sn0w.solert` | Rootless public source | Restyles `UIAlertController` with an iOS 26-inspired look on iOS 15+. |
| SwipeForMore7 | `com.futur3sn0w.swipeformore7` | iOS 7 compatibility fork | Brings SwipeForMore-style Cydia package actions to older iOS targets. |

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

## Package Repo

The `repo/` folder is reserved for package-repo output. Once enabled, it can host the files package managers expect, such as `Packages`, `Release`, and `.deb` files.

GitHub Pages URLs depend on how the site is published:

- If the GitHub repository slug is `repo`, its project site can live at `https://your-domain.example/repo/`.
- If this source repository uses another slug, files in `repo/` would normally publish below that project path, for example `https://your-domain.example/futur3sn0w-public-repo/repo/`.
- If the package repo should be exactly `https://your-domain.example/repo/`, use a dedicated GitHub repo named `repo`, publish from the main Pages site with a `/repo` folder, or use a GitHub Actions Pages workflow that publishes this folder as the site root.

For a cleaner package-manager URL, a subdomain such as `https://repo.your-domain.example/` is also a good option.

## Notes

`SwipeForMore7` is an iOS 7 compatibility fork of PoomSmart's MIT-licensed SwipeForMore project. The original license is preserved in `SwipeForMore/LICENSE`.
