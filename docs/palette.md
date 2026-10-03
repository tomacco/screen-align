# Palette: Calibration

Laser-level amber on instrument black in dark mode, ink on paper in light mode. Every colour is dynamic and follows the system appearance. The line colours come from the Okabe-Ito set, brightened for a dark backdrop, so they stay distinct under the common forms of colour blindness. The source of truth for the app is `Sources/ScreenAlign/Theme.swift`; the demo SVG and README badges use the same values.

| Token | Dark | Light | Use |
|-------|------|-------|-----|
| ink | `#0E1116` | `#F3F0E8` | Overlay backdrop, demo background |
| panel | `#171B22` | `#FFFFFF` | Info panel |
| panel edge | `#2A303A` | `#D9D4C7` | Panel outline, device bezels in the demo (`#232933`) |
| text | `#E8EAED` | `#1B1F24` | Panel text, cursor guide at 85% |
| muted text | `#8B93A1` | `#5E6672` | Secondary labels |
| amber | `#FFB020` | `#C77800` | Line 1, the primary accent |
| sky | `#56B4E9` | `#1F6FB2` | Line 2, links and badges |
| mint | `#2BD9A0` | `#0E9F6E` | Line 3, the aligned state |
| orchid | `#E58FC4` | `#B4508F` | Line 4 |
| vermillion | `#FF6A3D` | `#D4481B` | Line 5 |
| lemon | `#F0E442` | `#9A8A00` | Line 6 |

Roles: amber is the fixed line, sky is the line you move, mint means done or aligned. Cards use the native HUD material in dark mode and the popover material in light mode.
