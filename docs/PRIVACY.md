# Privacy

CleanerXcode never asks for your name, email or an account, and never requires sign-in.

## Usage statistics (Himetrica)

- Release builds configured with a Himetrica key send usage statistics through [Himetrica](https://www.himetrica.com):
  - which cleanup categories ran and the result;
  - a coarse freed-space range (for example "1-10GB");
  - taps on the social, donate and update links.
- Each event also carries a random installation ID and a session ID created by the Himetrica SDK, plus the app and macOS versions. These IDs are not linked to your hardware, Apple ID or name.
- Like any web request, Himetrica sees the connection's IP address.
- Usage statistics never include file paths, file names, simulator names, hardware identifiers or exact sizes.
- **Turn it off** in Settings › General › Privacy, "Send anonymous usage statistics" (on by default).

## Crash and error reports (Sentry)

- Builds configured with a Sentry DSN send crash reports through [Sentry](https://sentry.io).
- When a cleanup fails, they also send one summary report with:
  - the failed categories and error types, and counts;
  - the technical context the Sentry SDK attaches: Mac model and architecture, macOS, kernel and app versions, memory figures, screen size and locale.
- Before a report leaves your Mac:
  - paths inside your home folder become `~/…`;
  - temporary paths are replaced;
  - the user and computer names are removed;
  - the device hash the SDK derives from your network hardware is removed.
- Sessions are not tracked. Like any web request, Sentry sees the connection's IP address.

## Builds from source

The Himetrica key and the Sentry DSN live in the git-ignored `CleanerXcode/Secrets.xcconfig`. A build without that file works fully and sends nothing.

## Other network requests

- To check for updates, the app reads [`resources/version.json`](../resources/version.json) from GitHub.
- Downloading a runtime runs Apple's own `xcodebuild -downloadPlatform`, which talks only to Apple.
