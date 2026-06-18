# SevenEleven

`SevenEleven` is an incremental SpringBoard tweak for iOS 11 that aims to bring the app switcher closer to the iOS 7-8 look without trying to rewrite the entire switcher in one pass.

## Current phase

Phase 1 is intentionally small:

- manually restore a tappable Home card inside the switcher
- keep the rest of the switcher behavior as untouched as possible
- lay groundwork for later visual passes behind feature flags

## Planned phases

1. Restore the Home card cleanly and make its placement stable.
2. Reduce card size and normalize card geometry.
3. Remove the edge fade / cascade look.
4. Flatten scroll transforms so cards move more like iOS 7-8.
5. Revisit labels, shadows, spacing, and any leftover chrome.

## Notes

- I did not wire in a third-party package dependency yet because I could not verify a stable package name and repo from the sources available in this session.
- The first pass is view-hierarchy driven, which is a safer starting point than assuming deeper private constructors are stable on iOS 11.

## Build

```sh
make package
```

If your device SSH defaults are already configured:

```sh
make install
make do
```
