# CenterLastRow

A small SpringBoard tweak that centers the final row of icons on an icon page when that row is not full.

## Behavior

- Leaves full rows alone.
- Re-centers the final row when it contains fewer icons than the page's column count.
- Skips dock-style icon list views to avoid changing dock alignment.

## Build

```sh
make package
```

If your device SSH defaults are already configured:

```sh
make install
make do
```
