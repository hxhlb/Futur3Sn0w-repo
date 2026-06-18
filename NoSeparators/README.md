# NoSeparators

A small iOS 11 tweak that hides common UIKit separator lines systemwide on a best-effort basis.

## What it currently targets

- `UITableView` separators across apps.
- Shared interface-action separator views used by alerts, action sheets, and many 3D Touch shortcut-style menus.

## Important caveat

This is systemwide, but not literally universal. It will catch stock UIKit separators. Apps that draw their own hairlines with custom views, images, or Core Graphics will need additional one-off hooks.

## Preferences

The included PreferenceLoader bundle exposes:

- master enable switch
- table separators
- alert/action sheet separators
- shortcut / 3D Touch menu separators

Changes are reloaded with a Darwin notification. SpringBoard content is easiest to verify after a respring, while ordinary apps usually just need to be relaunched.

## Build

```sh
make package
```

If you already have device SSH defaults configured in your shell:

```sh
make install
make do
```
