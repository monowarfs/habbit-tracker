# CI/CD

GitHub Actions (the developer's existing platform — per
`00-project-context.md`, no new CI vendor introduced).

## PR workflow — format, analyze, test

Runs on every PR into `dev`, `staging`, or `main`. Caches `~/.pub-cache`
keyed on `pubspec.lock` so repeated runs don't re-download the same
package set.

`.github/workflows/pr.yml`:

```yaml
name: PR Checks

on:
  pull_request:
    branches: [dev, staging, main]

jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version-file: pubspec.yaml
          channel: stable

      - uses: actions/cache@v4
        with:
          path: ~/.pub-cache
          key: pub-${{ runner.os }}-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: pub-${{ runner.os }}-

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Check formatting
        run: dart format --output=none --set-exit-if-changed .

      - name: Analyze
        run: flutter analyze

      - name: Test
        run: flutter test
```

Generated code (`*.g.dart`/`*.freezed.dart`) is produced fresh in this job
— per `coding-standards.md`, these files aren't committed, so `analyze`/
`test` would fail immediately without this step; it isn't optional
CI ceremony.

## Tag workflow — signed Android AAB

Runs on any tag matching `v*` (`git-strategy.md`'s milestone tags).
Requires four repository secrets set up once:
`ANDROID_KEYSTORE_BASE64` (the release keystore file, base64-encoded),
`ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`.

`.github/workflows/release.yml`:

```yaml
name: Release Build

on:
  push:
    tags: ["v*"]

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version-file: pubspec.yaml
          channel: stable

      - uses: actions/cache@v4
        with:
          path: |
            ~/.pub-cache
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: gradle-${{ runner.os }}-${{ hashFiles('**/*.gradle*', '**/pubspec.lock') }}
          restore-keys: gradle-${{ runner.os }}-

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Decode signing keystore
        run: echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > android/app/release.keystore

      - name: Write key.properties
        run: |
          cat <<EOF > android/key.properties
          storePassword=${{ secrets.ANDROID_STORE_PASSWORD }}
          keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
          keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
          storeFile=release.keystore
          EOF

      - name: Build signed AAB
        run: flutter build appbundle --release

      - uses: actions/upload-artifact@v4
        with:
          name: app-release-aab
          path: build/app/outputs/bundle/release/app-release.aab

  build-ios:
    # Later-phase — see "iOS signing" below. Left as a placeholder job so
    # the workflow file's shape doesn't need restructuring once iOS
    # signing is actually provisioned; the job body is filled in then.
    if: false
    runs-on: macos-latest
    steps:
      - run: echo "iOS build/signing intentionally not wired up yet"
```

## iOS signing — outlined, marked later-phase

**Not wired up now, deliberately.** iOS release builds require:

1. A **macOS runner** (`runs-on: macos-latest`) — GitHub-hosted macOS
   runners cost more per minute than Linux runners, worth knowing before
   enabling this job to run on every tag rather than only real release
   candidates.
2. An **active Apple Developer Program enrollment** ($99/year) — does not
   exist yet at documentation-run time; this is a real account/paperwork
   step outside this codebase, not a config value.
3. **Signing certificates + provisioning profiles**, typically managed via
   either `fastlane match` (a shared, encrypted certificate repo) or
   manually exported `.p12`/`.mobileprovision` files stored as base64
   GitHub secrets, same pattern as the Android keystore above.
4. An **App Store Connect API key** (if automating the actual upload step
   via `xcrun altool`/`notarytool` or a `fastlane` lane), separate from the
   signing certificates themselves.

None of this can be filled in until the Apple Developer Program enrollment
exists — the placeholder `build-ios` job above exists so the workflow
file's overall shape (two build jobs per tag, one per platform) doesn't
need restructuring later, only its `if: false` flipped and its steps
filled in once that enrollment and its certificates exist.

## Play Store / App Store upload automation

**Not included in either workflow above.** Both `flutter build appbundle`
(Android) and its iOS equivalent produce a build artifact CI uploads as a
downloadable GitHub Actions artifact — actually publishing that artifact
to Play Console (via the Play Developer API + a service account) or App
Store Connect (via `altool`/`notarytool`/Transporter) is a further
automation step, deliberately left manual for now: the first few store
submissions benefit from a human reviewing exactly what's being uploaded
before it reaches a store's review queue, and automating that upload step
is easy to add later once the manual process has been done at least once
successfully.
