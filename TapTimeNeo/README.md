# TapTimeNeo

TapTimeNeo is a rootless revival of the old TapTime idea for modern iPhones. Tapping the status bar clock toggles the clock text to the current date in `MM/dd` format with a short fade, and it will automatically return to the clock after a few seconds if left on the date.

Behavior notes:

- It hooks `_UIStatusBarStringView` and only takes over strings that look like a clock.
- It uses the status bar's built-in alternate-text path when available so the transition stays close to stock behavior.
- It attaches its tap recognizer to the status bar container so the toggle is harder to trigger accidentally during other gestures.
