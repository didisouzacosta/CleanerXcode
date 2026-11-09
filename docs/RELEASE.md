# Releases

Every merge to `main` publishes a new version by itself (C42). This page explains the pipeline, the settings it needs, and how to stop or undo a release.

## How it works

1. **Pull request:** `CI` (`.github/workflows/ci.yml`) runs lint, the release tools' tests, the unit tests and an unsigned Release build. It needs no secret, so pull requests from forks run it too. Make it a required check on `main`.
2. **Merge to `main`:** `Release` (`.github/workflows/release.yml`) runs:
   1. **Checks:** the same checks again.
   2. **Plan:**
      - The bump comes from the merged pull request's labels: `release:minor`, `release:major` or `skip-release`. No label means a patch.
      - The version is the latest `v*` tag plus that bump. If the project's `MARKETING_VERSION` is already newer, it is used as is, which is how `1.0.0` follows `v0.7.0`.
      - The build is the number of commits on `main`, never at or below the project's build. Sparkle compares builds, so they only grow.
   3. **Release**, on the `xcode-27` runner with Xcode 27.2:
      - archives with the Developer ID certificate;
      - re-signs Sparkle's helpers (the XPC services are removed because the app is not sandboxed);
      - notarizes and staples the app, then builds, signs, notarizes and staples the DMG;
      - checks both with `spctl`;
      - zips the app and signs the zip with Sparkle's EdDSA key.
   4. **Publish**, in this order:
      - **R2:** the zip, the versioned DMG and `latest/CleanerXcode.dmg`;
      - **GitHub Release:** tag `vX.Y.Z` with the pull request's notes and the files (including `CleanerXcode.dmg`, for the README link);
      - **`appcast.xml` on R2:** the feed Sparkle reads, plus a snapshot in `appcasts/`;
      - **`resources/version.json` and `RELEASE_NOTES.md` on `main`:** a `[skip ci]` commit that also removes the old `releases/CleanerXcode.dmg`. Apps 0.7 and 1.0 builds without Sparkle still read this file;
      - **Sentry:** the dSYMs.
3. **In the app:**
   - a Release build with the feed and the key uses Sparkle: a daily check, the release notes and the install after the user confirms;
   - CleanerXcode › Check for Updates… and Settings › General › Updates.

   Any other build (Debug, or a fork without the settings) keeps reading `version.json`.

Run **Actions › Release › Run workflow** to publish by hand and pick the bump.

## Settings to create

Create the secrets in **Settings › Secrets and variables › Actions › Secrets** and the variables in the **Variables** tab of the same page. Nothing here goes into the repository.

### Apple (signing and notarization)

| Name | Type | Value |
| --- | --- | --- |
| `DEVELOPER_ID_CERTIFICATE_P12_BASE64` | Secret | Your "Developer ID Application" certificate with its private key, exported from Keychain Access as `.p12`, then `base64 -i cert.p12 \| pbcopy`. |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Secret | The password you chose when exporting the `.p12`. |
| `APPLE_API_KEY_ID` | Secret | The key ID of an App Store Connect API key (Users and Access › Integrations › App Store Connect API, role Developer or higher). |
| `APPLE_API_ISSUER_ID` | Secret | The issuer ID shown on the same page. |
| `APPLE_API_PRIVATE_KEY` | Secret | The full contents of the downloaded `AuthKey_<ID>.p8`, including the BEGIN and END lines. |

Create the certificate at developer.apple.com › Certificates › "Developer ID Application" if you don't have one yet. It must belong to the project's team, `MM4N959BB5`, which the workflow and `scripts/release/ExportOptions.plist` use.

### Sparkle (in-app updates)

| Name | Type | Value |
| --- | --- | --- |
| `SPARKLE_ED_PRIVATE_KEY` | Secret | The private EdDSA key. |
| `SPARKLE_PUBLIC_ED_KEY` | Variable | The public key, which is built into the app. |

To create the key pair, download `Sparkle-2.10.1.tar.xz` from Sparkle's GitHub releases, then:

```bash
./bin/generate_keys            # stores the pair in your login keychain and prints the public key
./bin/generate_keys -x sparkle-private-key.txt   # exports the private key for the secret
```

Keep a copy of the private key in a password manager and delete the exported file. **If the private key is lost, installed apps stop accepting updates.**

### Cloudflare R2 (downloads)

| Name | Type | Value |
| --- | --- | --- |
| `R2_ACCOUNT_ID` | Secret | Your Cloudflare account ID. |
| `R2_ACCESS_KEY_ID` | Secret | Access key of an R2 API token with Object Read & Write on the bucket only. |
| `R2_SECRET_ACCESS_KEY` | Secret | Its secret access key. |
| `R2_BUCKET` | Variable | The bucket name, for example `cleanerxcode-downloads`. |
| `DOWNLOADS_BASE_URL` | Variable | The bucket's public address over https, without a trailing slash, for example `https://downloads.example.com`. The feed becomes `<DOWNLOADS_BASE_URL>/appcast.xml`. |

In Cloudflare:
1. **R2 › Create bucket.**
2. **Settings › Custom Domains:** connect your domain. The `r2.dev` address works for tests, but it is rate-limited.
3. **R2 › Manage API tokens:** create a token with Object Read & Write limited to this bucket.

### Analytics and crash reports

| Name | Type | Value |
| --- | --- | --- |
| `HIMETRICA_API_KEY` | Secret | The Himetrica key. Optional: empty turns analytics off. |
| `SENTRY_DSN` | Secret | The Sentry DSN. Optional: empty turns crash reports off. |
| `SENTRY_AUTH_TOKEN` | Secret | A token with `project:releases`, for the dSYMs. Optional: without it the upload is skipped with a warning. |

### Repository settings

- **Labels:** create `release:minor`, `release:major` and `skip-release`.
- **Workflow permissions** (Settings › Actions › General): keep the default "Read repository contents". Each workflow asks for the write access it needs.
- **Protecting `main`:** after publishing, the release pushes a `[skip ci]` commit to `main` with `resources/version.json` (apps 0.7 read it) and `RELEASE_NOTES.md`. A rule that requires pull requests or status checks rejects that push from the default `GITHUB_TOKEN`. Pick one:
  - **No rule on direct pushes:** nothing else to do. Pull requests still show the `CI` check, and the release runs it again before publishing.
  - **With a ruleset on `main`** (Settings › Rules › Rulesets) that requires pull requests and the `CI / Lint, tests and Release build` check: add yourself (or Repository admin) to its bypass list. Then create a fine-grained personal access token limited to this repository with Contents: Read and write, and save it as the secret below.

| Name | Type | Value |
| --- | --- | --- |
| `RELEASE_PUSH_TOKEN` | Secret (optional) | The token that pushes `version.json` when a rule blocks `GITHUB_TOKEN`. It is used only in that step and in the rollback. Fine-grained tokens expire: note the date and renew it before then, or the push fails after the next release. |

If that push fails anyway, the release is already out on R2 and GitHub; update `resources/version.json` by hand with the values from the run.

## Stop or undo a release

- **Don't release a merge:** add the `skip-release` label before merging.
- **Undo:** run **Actions › Rollback › Run workflow** on `main` with the version and build to restore. It puts back:
  - that `appcast.xml`;
  - `latest/CleanerXcode.dmg` on R2;
  - the "Latest" GitHub Release that the README downloads;
  - `version.json`.

  Sparkle never offers an older build, so people who already installed the bad version keep it until the next release. Ship a fixed patch for them.
- **Several merges in a row:** releases run one at a time. GitHub keeps only one waiting run per group, so if three merges land while a release runs, the middle one is skipped and its changes ship with the next. Its `release:minor` or `release:major` label is lost, so start a run by hand with that bump if it matters. A rollback started while a release waits replaces that waiting release.

## Test locally

```bash
python3 -m unittest discover -s scripts/release -p 'test_*.py'
```

To try Sparkle on your Mac, set `SPARKLE_FEED_URL` and `SPARKLE_PUBLIC_ED_KEY` in `CleanerXcode/Secrets.xcconfig` and build Release. Debug builds never use Sparkle, because they share the bundle id and would be replaced by the published version.
