# CCSupport Battery Fix

Companion patch for CCSupport on iOS 15+.

When CCSupport is installed on some iOS 15+ setups, the system status bar can ignore the battery percentage toggle even though `SBShowBatteryPercentage` is enabled. This tweak leaves CCSupport untouched and nudges SpringBoard's modern `_UIBatteryView` to honor the system battery percentage preference.

The patch only changes `_UIBatteryView`'s `setShowsPercentage:` value when the system battery percentage preference is already enabled, so the stock Settings toggle remains in control.

If opa334 fixes the behavior upstream, this package can be removed without replacing CCSupport.

## Building

```sh
make package FINALPACKAGE=1
```
