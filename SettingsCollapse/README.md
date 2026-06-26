# ReSettings

Rootless-first iOS 15+ rewrite inspired by [shiftcmdk/SettingsCollapse](https://github.com/shiftcmdk/SettingsCollapse).

This version keeps the durable part of the idea:

- add an expand/collapse control to Settings groups
- persist collapsed state
- target `com.apple.Preferences`

This first pass intentionally does not recreate the old horizontally scrolling icon strip used by the 2020 tweak. That part was tightly coupled to older `PSUIPrefsListController` table internals, while the group-collapse behavior itself is much more likely to survive on iOS 15/16.

## Build

```sh
env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache make clean package
```
