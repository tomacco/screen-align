# How ScreenAlign works

## Coordinate spaces

macOS places every screen in one global space measured in points. The main display has its top-left corner at (0, 0), x grows to the right and y grows downward. Each other screen has an origin in that space. When the cursor leaves one screen, macOS keeps its global coordinate and finds the screen that contains it. So the cursor crosses a bezel without a jump only when the same global height is the same physical height on both screens.

ScreenAlign stores each line as a distance from the top edge of its own screen (from the left edge, for vertical lines). The global position of a line is the screen origin plus that distance.

## The correction

For every screen except the main one, and for every line `k`:

```
shift(k) = (main.origin + mainLine(k)) - (screen.origin + screenLine(k))
```

That is how far the screen has to move so its line lands at the same global position as the line on the main display. With several lines, ScreenAlign writes the average and reports the spread between the largest and smallest shift.

Horizontal lines produce a shift in y, for screens side by side. Vertical lines produce a shift in x, for screens stacked on top of each other. A screen only takes part in a pass when its span along that axis overlaps the main display's span, which is why a mixed layout needs one pass per axis.

## Scale mismatch

A shift is a whole number of points, and a point is a different physical size on screens with different pixel density or scaling. A 27" 5K screen at 2560x1440 points and a 14" laptop at 1512x982 points do not have the same number of points per centimetre. Two lines far apart then need different shifts, and no single origin satisfies both. The cursor still crosses correctly at one height, and the error grows with distance from it. The fix is outside the arrangement: choose scaled resolutions that bring the points-per-centimetre of the screens closer.

## What gets written

`CGBeginDisplayConfiguration`, then `CGConfigureDisplayOrigin` for each moved screen, then `CGCompleteDisplayConfiguration` with `.permanently`. This is the public Core Graphics API for changing the arrangement. macOS stores the result in `/Library/Preferences/com.apple.windowserver.displays.plist` and a per-host copy under `~/Library/Preferences/ByHost/`. ScreenAlign does not edit those files directly.

macOS may adjust an origin it is given so that screens stay edge to edge. A vertical shift of a screen placed beside the main display does not break that contact unless the shift is larger than the overlap, so in practice the written origin is the one computed.

Undo (U) writes the origins recorded before the last apply.

## Known limits

- The main display is always the reference. A screen that touches only another external screen (for example, a monitor above a side monitor) cannot be corrected yet.
- Mirrored screens are skipped; they share the frame of the screen they mirror.
- Sub-point precision is not possible: the arrangement only accepts whole points.
