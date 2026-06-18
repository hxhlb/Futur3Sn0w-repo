# Solert

`Solert` is a rootless iOS 15 tweak concept that restyles `UIAlertController` to feel closer to the iOS 26 visual language without leaning on glass-heavy materials.

## Current PoC

- Hooks `_UIAlertControllerView` to round the alert card and give it a softer card background.
- Hooks `_UIAlertControllerActionView` to turn stock actions into distinct rounded button capsules.
- Preserves the existing alert behavior instead of replacing button handling.

## Known class targets

- Main alert body: `_UIAlertControllerView`
- Alert actions: `_UIAlertControllerActionView`

## Test targets

The initial filter is intentionally narrow for safer iteration:

- `com.apple.Preferences`
- `com.apple.mobilesafari`
- `com.apple.mobileslideshow`
- `is.workflow.my.app`
- `com.apple.springboard`

## Build notes

This repo is scaffolded for Theos, but the local environment does not currently expose `THEOS` or `nic.pl`. Once Theos is installed/configured, the typical flow should be:

```sh
make package
make install
```

## Good next steps

- Inspect the alert view tree on-device with FLEX to identify title, message, separator, and backdrop classes precisely.
- Differentiate preferred actions from neutral actions instead of only detecting destructive styling.
- Add a dimming-overlay style pass so the full alert presentation feels more modern, not just the card itself.
- Expand the process filter once the styling is stable.
