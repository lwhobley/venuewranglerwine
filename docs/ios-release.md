# Expo EAS iOS build preparation

Bundle identifier: **`venuewranglerwine`**. Expo slug: **`venuewranglerwine`**.
All native Runner configurations and app.json use that exact identifier.

This Flutter app uses Expo EAS's custom native build service. The custom workflow
installs Flutter 3.47.5, generates Dart code and iOS configuration, installs
CocoaPods, applies EAS-managed signing, and archives/exports the IPA.
The package.json is build-tool metadata; the app still runs Flutter.

## First build

From the repository root:

```sh
npx eas-cli@latest login
npx eas-cli@latest init
npx eas-cli@latest credentials --platform ios
```

The init command links your Expo project and adds its actual project ID to
app.json. Select the Apple team and credentials for `venuewranglerwine`.

Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in the project's EAS **production**
environment. Use the public client key, never a service-role key. The custom
builder creates an ignored Flutter defines file from those values.

```sh
npx eas-cli@latest build --platform ios --profile production
```

This preparation does not start a cloud build or submit anything to Apple.
EAS cloud builds use your Expo account's plan resources.

## Version and identity

Set the desired version/build number in `pubspec.yaml` before a build. The custom
workflow uses Flutter's local version, currently `1.0.0+1`; increase the build
number for each upload. Inspect the resulting IPA's Info.plist to confirm
`CFBundleIdentifier`, `CFBundleShortVersionString`, and `CFBundleVersion`.

The requested `venuewranglerwine` differs from the earlier original-app bundle
`com.venuewrangler.app`, so it does not target that original listing's updates.
Apple must provision the requested identifier before a signed build can succeed.

## Verification

Configuration checks run locally. Compilation/signing need the EAS macOS builder
and linked Expo/Apple credentials; no EAS cloud build has been run yet.
iOS Firebase/APNs push configuration is separate from this build setup.

Reference: [Expo custom builds](https://docs.expo.dev/custom-builds/get-started/).

## Apple setup verified on September 29, 2026

| Item | Value/status |
| --- | --- |
| Apple Developer team | LIFFORT HOBLEY, `8MTB6AL22R` |
| Registered App ID | `venuewranglerwine` (explicit) |
| Identifier description | Venue Wrangler Wine |
| Push Notifications capability | Enabled |
| App Store Connect app | Venue Wrangler Wine, Apple ID `6817233267` |
| Original app | `com.venuewrangler.app`, Apple ID `6772533789`; a separate listing |
| Distribution certificate | Apple Distribution certificate `3BR8ZA87G6`, expires September 29, 2027; issued after CSR upload |
| Provisioning profile | App Store profile configured for `8MTB6AL22R.venuewranglerwine` and the new certificate; Generate awaits signing confirmation |

The App Store Connect record is a preparation record, not a released app.
The CSR contains the public signing request. The encrypted private signing key
and its password are kept outside this Git repository in the task's local
`apple-signing` output directory. They are not application assets.

The EAS submission profile points to the new Apple ID. No cloud build,
binary upload, review submission or release has been started. Expo project
linking and installation of the completed signing credentials remain necessary.

The September 29 certificate was subsequently located in Downloads and matched
to the September 24 `distribution.key`. It was exported as
`VenueWranglerWine-AppleDistribution-20260929.p12`, protected with the saved
signing password, and its password and certificate were verified locally.
The separately generated September 29 private key does not match this certificate.
The .p12 and password remain outside Git. A matching App Store provisioning
profile and installation in the selected build service remain necessary.

For the Codemagic workflow and exact variable groups, see
[Codemagic iOS builds](codemagic-ios.md).
