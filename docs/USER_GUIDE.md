# User guide

CleanerXcode shows how much space Xcode is using and removes what you choose. This guide covers each page, each item and what happens when it is removed.

## The window

- **Overview:** the total you can free, a breakdown by section, a card for Simulators and runtimes and one for each section, and the Clean button.
- **Sections:** Xcode, Simulators, Temporary files and User data. Each one lists its items, with the current size and a switch for each.
- **Simulators and runtimes:** your simulators and runtimes, with size and last use. From here you can delete them or download new runtimes.
- **Settings:** General and About, at the bottom of the sidebar.
- **Action bar:** always visible at the bottom of the cleanup pages, with the selected total and the main action.

Use ⌘1–⌘8 to jump between pages and ⌃⌘S to show or hide the sidebar.

## How a cleanup works

1. Choose the items. Your choices are saved.
2. Press **Clean**.
   - Risky items ask for confirmation first, naming each item and its effect.
   - If Xcode or Simulator is open, CleanerXcode warns you. Some items wait until Xcode is closed.
3. Follow the progress. You can **Cancel** at any time; items already removed stay removed.
4. Read the report: what was removed, skipped or failed. **Try again** reruns only the failures.

## Items and their risk

- **Safe:** comes back by itself; the only cost is time.
- **Attention:** a cost you will notice, like downloading again or a slower first build.
- **Dangerous:** your own data, hard to get back.

Items marked "Trash" go to the Trash; the space is freed only when you empty it. The others are removed for good.

### Xcode

| Item | Risk | On by default | What happens |
|---|---|---|---|
| DerivedData | Safe | Yes | Builds and indexes; Xcode rebuilds them. |
| Xcode and package manager caches | Safe | Yes | Xcode, xcodebuild, CocoaPods and Carthage caches. |
| Device Support | Attention | No | Copied again when a device connects, so the first debug is slower. |
| SwiftPM cache | Attention | No | Packages are downloaded again on the next build. Builds offline fail until then. |
| Products | Attention | No | Build products exported by Xcode. |

### Simulators

| Item | Risk | On by default | What happens |
|---|---|---|---|
| Orphan simulator temporary files | Safe | Yes | Temporary folders with no matching simulator. |
| CoreSimulator caches and logs | Safe | Yes | Restarts the simulator service, without restarting the Mac. |
| Preview and test simulators | Safe | Yes | Simulators used by SwiftUI Previews, XCTest and Playgrounds. |
| Unavailable simulators | Safe | No | Simulators from runtimes that no longer exist. |
| Erase the content of every simulator | Attention | No | Keeps the simulators and removes their apps and data. |

### Temporary files

| Item | Risk | On by default | What happens |
|---|---|---|---|
| Temporary folder | Attention | No | Old files from AI tools and terminals in `$TMPDIR` and `/tmp`. Only items older than the minimum age (Settings, 3 days by default) are removed. |

### User data

| Item | Risk | On by default | What happens |
|---|---|---|---|
| Archives | Dangerous | No | Trash. Holds the dSYMs you need to symbolicate crashes and resubmit builds. |
| Xcode user data | Dangerous | No | Trash. Themes, shortcuts, snippets and breakpoints. Waits until Xcode is closed. |
| Provisioning Profiles | Dangerous | No | Trash. Xcode downloads them again when signing. |
| Reset Xcode preferences | Dangerous | No | Resets the DerivedData location, behaviors and window state. Waits until Xcode is closed. |

## Simulators and runtimes

- **Simulators:** select the ones to delete. "Select duplicates" picks every duplicate in one click. CleanerXcode asks before deleting and shuts down running simulators first.
- **Runtimes:** deleting a runtime also removes the simulators that use it, and getting it back means a download of several GB.
- **Download runtimes:** choose iOS, watchOS, tvOS or visionOS.
  - CleanerXcode downloads the runtime that matches the selected Xcode, one at a time.
  - To test on an older system, pick an earlier version in the platform's menu. The menu lists the final versions Apple offers for download that are older than your Xcode and not installed yet, with their size. Picking a version also selects the platform.
  - The earlier versions load while the sheet is open. Without a network connection, CleanerXcode uses the list it read in the last 30 days; without one, it offers only the version that matches Xcode, with "Try again".
  - If Xcode doesn't accept a version, the download ends as "Not available for the selected Xcode" without downloading anything.
  - The card shows how much of the current runtime has arrived and, after a few seconds, about how long is left. When Xcode does not report it, the card shows a spinner instead.
  - Each new runtime appears in the list as soon as it is installed.
  - The download continues if you leave the page, and stops if you quit the app.

## Menu bar

When "Show in the menu bar" is on (Settings › General), the menu bar shows the space you can free. From there you can:

- start a cleanup;
- see the result;
- open the window.

Closing the window keeps CleanerXcode running in the menu bar.

The size stays up to date even with the window closed. CleanerXcode follows the measured folders in real time: about 5 seconds after a folder stops changing (a build ends, an archive is created), it measures that category again, and while a folder keeps changing it measures it at most once a minute. This covers every category measured on disk, selected or not; the temporary files, the orphan simulator folders and the old simulators are only updated by the complete measurement, which still runs about 30 seconds after the app opens and then every 30 minutes. The last size stays on screen while it measures, and nothing runs while the folders do not change. Everything waits during a cleanup or while simulators are being deleted, and pauses in Low Power Mode, when the Mac is hot and while the Mac sleeps. Turning off "Show the size that can be freed" stops both. The gear in the menu bar panel opens Settings › General.

## Settings

Settings are pages in the sidebar, under Settings. Open them with ⌘, (CleanerXcode › Settings…), ⌘7 or ⌘8, or the gear in the menu bar panel.

- **General:**
  - open at login;
  - menu bar options;
  - the minimum age for temporary files;
  - anonymous usage statistics (see [PRIVACY.md](PRIVACY.md)).
- **About:** version, updates, links, the dedication and donations.

Every fifth successful cleanup, the result also asks for support: "Support the project" opens a short note about donating, with "Donate any amount" (Stripe, in your browser) and "Not now". "Close" dismisses the result as usual.

## Updates

CleanerXcode checks GitHub for a new version. When there is one, a small round button with an arrow appears next to the version, at the bottom of the sidebar and on the About page; it opens the download.
