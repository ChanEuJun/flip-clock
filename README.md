# flip-clock

**FlipFocus** — a minimal, native macOS flip-style clock and focus timer, built to sit in a tall strip beside your work on a second screen.

- **Clock** — hours, minutes and seconds as split-flap style tiles, stacked vertically (or in one row when the window is wide enough).
- **Timer** — click a row and type to set it; tracks focus sessions for the day.
- **Stats** — a GitHub-style heatmap of daily focus minutes, plus today's sessions and your streak.

Native SwiftUI, no web runtime: ~35 MB memory and ~1% CPU while running.

## Build & run

Requires macOS 14+ and Xcode (or the Swift toolchain).

```bash
./build.sh && open build/FlipFocus.app
```

The app opens at full screen height against the nearer screen edge, at a fixed width-to-height ratio, so it looks the same on any monitor.

## Keyboard shortcuts

### Modes

| Shortcut | Action |
| --- | --- |
| `⌘1` | Clock |
| `⌘2` | Timer |
| `⌘3` | Stats |

### Timer

| Shortcut | Action |
| --- | --- |
| `⌘↩` | Start / pause / resume the timer |
| `⌘.` | Stop the timer |

### Setting the timer (while the timer is stopped)

Click the hours, minutes or seconds row to start typing into it. Clicking a row in clock mode switches to the timer.

| Key | Action |
| --- | --- |
| `0`–`9` | Type digits (last two digits typed are kept) |
| `⌫` | Delete the last digit |
| `Tab` / `⇧Tab` | Move to the next / previous row |
| `↩` or click elsewhere | Confirm |
| `Esc` | Cancel the edit |

Hours go up to 99; minutes and seconds up to 59.

### Window

| Shortcut | Action |
| --- | --- |
| `⌘0` | Reset window size (full height, default ratio, nearer edge) |
| `⌘⌥→` | Snap to right edge |
| `⌘⌥←` | Snap to left edge |
| `⌘⇧T` | Keep on top |

## Focus tracking

- A **session** counts when the timer reaches zero.
- Stopping early still adds the minutes focused (if at least one) to that day's **focus time**, but not to the session count.
- The heatmap shades each day by total focus minutes; hover a square for details.

Data is stored locally in `~/Library/Application Support/FlipFocus/sessions.json` and written only when a session ends.
