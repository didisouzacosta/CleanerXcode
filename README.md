<p align="center">
  <image src="resources/app-icon.png" width="200" />
</p>

<p align="center">
  <a href="https://github.com/didisouzacosta/CleanerXcode/raw/refs/heads/main/releases/CleanerXcode.dmg">
    <image src="resources/download-button.png" width="200" />
  </a>
</p>

<h1 align="center">CleanerXcode (BETA)</h1>

### What is CleanerXcode?
CleanerXcode is a macOS tool designed to remove unnecessary Xcode files, such as Derived Data, build caches, device support files, and simulator data. It helps keep your development environment clean and efficient.

### Why use it?
Xcode can accumulate a large number of temporary files and data that take up disk space and may affect system performance. CleanerXcode solves this problem by providing a simple and effective way to free up space and improve your workflow speed.

<div align="center">
  <video src="https://github.com/user-attachments/assets/8ec7d018-04e0-43c3-900b-330e76dc30b8"/>
</div>

## Key Features
- **Temporary file removal:** Deletes Derived Data, build caches, and other temporary Xcode files.
- **Device support cleanup:** Removes outdated device support and simulator data.
- **Simulator management:** Allows the removal of obsolete simulators, keeping only the essentials.
- **Intuitive interface:** Easy to use, with clear options for managing Xcode files.

## Requirements

| Platform                                             | 
| ---------------------------------------------------- |
| macOS 15.0+

## Installation & Usage
1. [Download CleanerXcode](https://github.com/didisouzacosta/CleanerXcode/raw/refs/heads/main/releases/CleanerXcode.dmg).
2. Open the application and select the desired cleaning options.
3. Click the clean button and wait for the process to complete.

## Areas for Improvement
- Support for advanced customization of file removal.
- Integration with macOS shortcuts for automated cleaning.
- Interface improvements for visualizing freed-up space.

## Privacy And Usage Policy
- This app doesn't ask for or collect your name, email or account data, and never requires sign-in or sign-up.
- Release builds configured with a Himetrica key send usage statistics through [Himetrica](https://www.himetrica.com): which cleanup categories ran, the result, a coarse freed-space range (for example "1-10GB") and taps on the social, donate and update links.
- Each event also carries a random installation ID and a session ID created by the Himetrica SDK (not linked to your hardware, Apple ID or name) and the app and macOS versions; like any web request, Himetrica sees the connection's IP address.
- Usage statistics never include file paths, file names, simulator names, hardware identifiers or exact sizes.
- A "Send usage statistics" switch (on by default) turns this off. It arrives with the new Settings screen, and no release build with a Himetrica key is distributed before it.
- Builds configured with a Sentry DSN send crash reports and, when a cleanup fails, one summary report through [Sentry](https://sentry.io): the stack trace, the failed cleanup categories and error types, counts, and the technical context the Sentry SDK attaches (Mac model and architecture, macOS, kernel and app versions, memory figures, screen size and locale).
- Before a report leaves your Mac, paths inside your home folder become `~/…`, temporary paths are replaced, the user and computer names are removed, and so is the device hash the SDK derives from your network hardware. Sessions are not tracked. Like any web request, Sentry sees the connection's IP address.
- This app is totally free and open source under the MIT license.

## Contribution Guidelines

### How to Contribute
- **Report Bugs:** Open an issue using this [link](https://github.com/didisouzacosta/CleanerXcode/issues/new/choose).
- **Suggest Improvements:** Submit a proposal via [issue](https://github.com/didisouzacosta/CleanerXcode/issues/new/choose) or pull request.
- **Submit Code:** Fork the repository, create a branch with your changes, and submit a pull request.

Feel free to contribute and help improve CleanerXcode!

### Coding Standards
- Follow best practices for Swift and macOS development.
- Include clear documentation and explanatory comments in the code.
- Analytics and crash reporting keys live in the git-ignored `CleanerXcode/Secrets.xcconfig` (copy `Secrets.example.xcconfig`). Without it the app builds with analytics and crash reporting disabled.

### License

This project is licensed under the MIT License. You are free to use, modify, and distribute it as long as you include the original license terms. See the [LICENSE file](https://github.com/didisouzacosta/CleanerXcode/blob/v0.1.1/LICENSE) for more details.

### Dependencies
• [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin-Modern)
• [Timeout](https://github.com/swhitty/swift-timeout)
• [Himetrica](https://github.com/himetrica/himetrica-swift) (anonymous product analytics)
• [Sentry](https://github.com/getsentry/sentry-cocoa) (crash and error reporting)

### Didication

This simple app was made for anyone who loves developing for Apple technologies.
I'd like to dedicate this app to my son Orlando and my wife Gisele.

### Special thanks

My sincere thanks for [Lesley](https://github.com/lesleyandrez) and [Nic](https://github.com/ngimelliUW) for all help.

### Donate

If this project help you, consider make a [donation](https://buy.stripe.com/00gcN772R2ns3wA9AA).

