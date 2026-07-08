# InMyFace

A tiny macOS menubar app that throws your next meeting **in your face** — a
full-screen takeover across every display with **Join**, **Snooze**, and
**Dismiss**. Plus the feature the original [In Your Face](https://www.inyourface.app/)
doesn't have: pick any upcoming meeting and set a **"remind me in N minutes"**
nudge.

Reads your calendars through macOS's native EventKit, so any calendar you've
added to **Calendar.app** — including your Google work calendar — just works.
No Google Cloud project, no OAuth, no accounts.

## Features

- **Menubar-only** (no Dock icon). Shows the countdown to your next meeting.
- **Full-screen takeover** on all monitors when a meeting is about to start.
- **Join** opens the Meet / Zoom / Teams / Webex link pulled from the event.
- **Snooze** (default 5 min) and **Dismiss**.
- **Remind me in N min** — per-meeting one-off nudges (1 / 5 / 10 / 15 / 30).
- **Settings**: lead time (at-start up to 5 min before), snooze length, and an
  "only meetings with a join link" filter.

## Requirements

- macOS 14 (Sonoma) or later
- Your work calendar added to **System Settings → Internet Accounts** so it
  shows up in Calendar.app

## Build & run

```
./scripts/build.sh
open dist/InMyFace.app
```

Or with [`just`](https://github.com/casey/just) (`brew install just`):

```
just build      # build the release .app
just update     # pull latest, rebuild, and restart the running app
just restart    # rebuild + restart without pulling
just build-dev  # debug build with the Developer menu
just test       # run tests
just package     # zip a distributable bundle
```

For a **debug build** with a **Developer** menu (overlay previews, including the
split layout, without waiting for a real meeting):

```
./scripts/build.sh debug
open dist/InMyFace.app
```

The Developer menu is compiled in only for debug builds (`DEVELOPER` flag in
`Package.swift`), so release builds stay clean.

First launch: macOS asks for **Calendar** access — allow it. If you ever miss
the prompt, use the menubar → **Open Privacy Settings…**.

Because the app is ad-hoc signed (no paid Apple Developer account), the very
first launch may need a right-click → **Open** to get past Gatekeeper.

## How triggering works

Every 10 seconds the app checks your next 24h of events. When one is within the
lead time of starting (and not dismissed or snoozed), the takeover appears.
"Remind me in N min" nudges fire independently at the time you set, regardless
of when the meeting actually starts.

## Project layout

| File | Role |
|------|------|
| `CalendarService.swift` | EventKit access + fetching meetings |
| `MeetingLink.swift` | Pulls the join URL out of an event |
| `MeetingScheduler.swift` | Decides *when* to nudge; owns all trigger state |
| `OverlayController.swift` / `OverlayView.swift` | The full-screen takeover |
| `MenuBarController.swift` | The status-bar menu |
| `AppDelegate.swift` | Wires it all together |

## Settings & sharing across Macs

Shareable settings (timing, sound, menu-bar style, launch-at-login, and your
per-calendar enable/keyword choices) are stored as JSON at:

```
~/Library/Mobile Documents/com~apple~CloudDocs/settings/inmyface.json
```

(falls back to `~/Library/Application Support/InMyFace/` if iCloud Drive isn't
present). Because it lives in iCloud Drive, the same config follows you to
another Mac automatically. Calendar settings are keyed by *account › calendar
name* (not the machine-local identifier) and stored as a **disabled** list, so
a calendar that only exists on the other Mac stays enabled by default there.

Machine-local runtime state (which meetings you've already dismissed) is kept
separately in UserDefaults and is *not* shared.

## Launch at login

Toggle **Settings → Launch at login** in the menu (registers via
`SMAppService`). No need to add it manually in System Settings.
