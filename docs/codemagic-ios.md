# Codemagic iOS builds

The repository-root `codemagic.yaml` builds the Flutter app for the registered
bundle `venuewranglerwine`, Apple team `8MTB6AL22R`, and App Store Connect app
`6817233267`. It uses Flutter 3.47.5, a macOS M2 builder, and the current Xcode
image. The native minimum iOS version is 15.5.

## Configure Codemagic

Connect `lwhobley/venuewranglerwine`, select `master`, and scan for
`codemagic.yaml` after this file has been committed and pushed.

### Variable group: app_config

| Name | Value |
| --- | --- |
| `SUPABASE_URL` | `https://aqhxbvaeuenqoljwwfcw.supabase.co` |
| `SUPABASE_ANON_KEY` | The public client key for that Supabase project |

Mark the client key Secret to suppress it in build logs. It is embedded in the
app by design; database authorization must remain server-enforced. Never put a
Supabase service-role key in the mobile app.

Optional variables in this group:

- `REQUIRE_EMAIL_VERIFICATION`: `true` by default; accepts `true` or `false`.
- `BUILD_NUMBER`: positive integer override, higher than all previous uploads.

The helper writes client values to an ignored defines file and passes its path
to Flutter. Merely defining environment variables does not configure Dart.

### Signing identities

Under Team settings > Code signing identities > iOS certificates, upload
`VenueWranglerWine-AppleDistribution-20260929.p12` and enter the password from
the corresponding `signing-password.txt`. Both files are outside Git.

Under iOS provisioning profiles, upload or fetch an **App Store** profile for
`venuewranglerwine`, team `8MTB6AL22R`, that includes this exact distribution
certificate. Confirm that Codemagic shows a matching certificate for the profile.
The .p12 alone is insufficient for signing an App Store IPA.

The current workflow uses uploaded signing identities through `ios_signing`;
it does not require a `CERTIFICATE_PRIVATE_KEY` environment variable. Codemagic
imports the uploaded .p12 with its password.

### Variable group: appstore_credentials

Only the `ios-testflight` workflow requires this group:

| Name | Value |
| --- | --- |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | Team API Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Team API Issuer ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Complete contents of the matching .p8 file |

Mark the private key Secret. Confirm the key is active for the correct team and
has suitable App Manager access; a filename does not prove authorization.

## Run a workflow

- **ios-release**: analyze, test, archive, verify, and provide a signed IPA.
- **ios-testflight**: the same build, then upload to App Store Connect and submit
  for TestFlight beta review. No tester group is assumed. Configure tester groups
  in App Store Connect. App Store review submission is disabled.

Neither workflow has automatic push or pull-request triggers. Start the desired
workflow manually after configuring its variables and signing identities.

Build numbers default to the pubspec build number plus Codemagic's project build
counter plus one. If another service has already uploaded a higher number, set
`BUILD_NUMBER` explicitly; the workflow does not query Apple for the latest build.
Do not run simultaneous uploads with the same explicit number.

The pipeline regenerates Dart models, runs analysis/tests, prepares Flutter's iOS
configuration before CocoaPods, applies signing profiles, and verifies the
archive's bundle, build number, signature, team, and the exported IPA's identity.
The defines file and all private credentials are excluded from artifacts.

iOS Firebase/APNs configuration remains separate; Android's
`google-services.json` does not configure iOS push delivery.

## Verification scope

Local YAML parsing and script checks establish configuration correctness only.
A signed iOS build must still run on Codemagic with the completed provisioning
profile. No Codemagic build or Apple upload was started when preparing this file.

References:
- [Codemagic Flutter builds](https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/)
- [App Store Connect publishing](https://docs.codemagic.io/yaml-publishing/app-store-connect/)
