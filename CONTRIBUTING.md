# Contributing

Thanks for helping. Bug reports, ideas and pull requests are all welcome.

## Report a bug or suggest an idea

[Open an issue](https://github.com/didisouzacosta/CleanerXcode/issues/new/choose). For a bug, include your macOS and Xcode versions, what you did, what you expected and what happened.

## Build from source

1. Install Xcode 26 or later.
2. Clone the repository and open `CleanerXcode.xcodeproj`.
3. Run the `CleanerXcode` scheme.

You don't need any key. Without `CleanerXcode/Secrets.xcconfig` the app builds and works fully, with analytics and crash reporting off. To test them, copy `CleanerXcode/Secrets.example.xcconfig` to `CleanerXcode/Secrets.xcconfig` and fill in your own keys. That file is git-ignored; never commit keys.

## Before you open a pull request

- **Tests:** add or update unit tests for any behavior change. Write the failing test first. Tests must never touch real data, the Trash, `simctl` or the network. Use the fakes in `Tests/Support`. Don't add UI tests.
- **Run the suite:**

  ```bash
  xcodebuild test -project CleanerXcode.xcodeproj -scheme CleanerXcode -destination 'platform=macOS'
  ```

- **Lint:** run `scripts/lint-swift.sh --fix`, then `scripts/lint-swift.sh`. It must finish with no violations, and the build must have no warnings.
- **Style:** follow `.ai/SWIFT_REFERENCE.md`, which comes from a submodule (run `git submodule update --init` first):
  - `// MARK:` sections in every type;
  - `let` and `var` groups kept apart;
  - a blank line between blocks of logic.
- **Text:** every user-facing string goes in `CleanerXcode/Resources/Localizable.xcstrings`, in English and Brazilian Portuguese.
- **Screens:** for UI changes, attach before-and-after screenshots in light and dark mode.
- **Dependencies:** open an issue before adding a third-party dependency.

Keep each pull request focused on one change and explain why it is needed.

## License

By contributing, you agree that your contribution is licensed under the [MIT license](LICENSE).
