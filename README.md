# Ergonomics Timer

A Windows tray app that prompts you to stand up and stretch for 10 minutes at ten-to
each hour through the workday (9:50 through 16:50 by default).

When an alert fires, an always-on-top window appears with a 10 minute countdown, a
**Snooze 5 min** button, and **Done**. It closes itself 15 seconds after the countdown
finishes.

## Requirements

Windows with PowerShell 5.1 (built in). No modules or downloads.

## Install

```powershell
.\Install.ps1
```

This registers a scheduled task named `ErgonomicsTimer` that starts the app at logon
(30 second delay), and starts it immediately so the tray icon appears right away. No
administrator rights are needed — the task runs as the current user.

Use `-NoStart` to register the task without launching now.

## Tray menu

Right-click the tray icon:

| Item | Behaviour |
| --- | --- |
| `Next: 3:50 PM` | Next scheduled alert, or snooze/pause status. Not clickable. |
| **Stretch now** | Starts a stretch break immediately. Double-clicking the icon does the same. |
| **Sound** | Toggles the chime. Off by default; the change is saved to `config.json`. |
| **Pause for today** | Suppresses remaining alerts until tomorrow. |
| **Open folder** | Opens this directory in Explorer. |
| **Exit** | Quits. It will start again at next logon. |

## Configuration

Edit `config.json`, then restart the app (Exit from the tray menu, then run
`run-hidden.vbs` or `.\Install.ps1`).

| Key | Default | Meaning |
| --- | --- | --- |
| `times` | `09:50` … `16:50` | Alert times, 24-hour `HH:mm`. Add or remove entries freely. |
| `stretchMinutes` | `10` | Countdown length. |
| `snoozeMinutes` | `5` | Snooze length. |
| `sound` | `false` | Play a chime when an alert opens and when the countdown ends. |
| `weekdaysOnly` | `true` | Skip Saturday and Sunday. |

## Uninstall

```powershell
.\Uninstall.ps1
```

Removes the scheduled task. Exit the running instance from the tray menu, or it stays
until logoff.

## Files

| File | Role |
| --- | --- |
| `ErgonomicsTimer.ps1` | Tray icon, menu, and the scheduler loop. The resident process. |
| `Alert.ps1` | `Show-StretchAlert` — the countdown window. |
| `run-hidden.vbs` | Launches the app with no console window. |
| `Install.ps1` / `Uninstall.ps1` | Scheduled task registration. |
| `config.json` | Settings, above. |

## Troubleshooting

The app logs to `%TEMP%\ergonomics-timer.log` — startup, each alert fired, and any
errors. PowerShell swallows exceptions raised inside WinForms event handlers, so this
log is the only visibility into a failure.

If launching does nothing, an instance is probably already running: it holds a named
mutex and shows an "already running" dialog rather than starting a second tray icon.
