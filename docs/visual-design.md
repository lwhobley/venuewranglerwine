# Hospitality visual refresh

## Design

The app uses warm ivory surfaces, wine-colored primary actions, olive dark
surfaces, muted brass accents, Fraunces editorial headings and Source Sans 3
body text. Rounded cards, generous spacing, clear section introductions and
short entrance transitions create a calmer, more expressive workspace.

Updated: shared theme, sign-in/registration frame, Tonight dashboard, responsive
navigation, and Cellar, Host, People and Business page headings. Permission
checks and operational write paths are preserved. Phone navigation shows up to
five destinations, with a More sheet when additional destinations exist.
Desktop retains all destinations in an extended navigation rail.

The hero is illustrative brand artwork, not a photograph of the selected venue.
Its file and both fonts are bundled for offline rendering. Font licenses ship
with the app and are registered with Flutter's license registry. Entrance motion
is omitted when the device requests reduced motion.

## Asset provenance

- Image: `assets/images/hospitality.png`, generated using the built-in imagegen
  tool. Original output was copied into this repository.
- Fonts: `assets/fonts/Fraunces.ttf` and `assets/fonts/SourceSans3.ttf` from
  Google's [font repository](https://github.com/google/fonts), under the included
  SIL Open Font Licenses.

Image generation prompt:

> Create a photorealistic editorial architectural photograph for a premium
> hospitality management app background. A beautiful intimate wine restaurant
> at golden hour with soft glowing pendant lights, honey colored oak tables
> elegantly set with wine glasses and linen, curved olive green banquettes,
> warm plaster walls, natural greenery, tall arched windows framing softly
> sunlit vineyards. Quiet inviting elegance, realistic materials and refined
> restrained decor. Wide landscape composition, no people, no text, no logos,
> no graphic overlays. Natural photographic lighting, rich warm depth, subtle
> film grain. Deliver a landscape image usable as a cropped dashboard hero
> and sign-in background.

## Verification

Seven focused widget tests pass. They check sign-in validation with enlarged
text and reduced motion at phone and desktop sizes, reachability of owner
workspaces through More in both themes, and restricted member shortcuts.
The rendered dashboard previews use fixture membership and venue data; they
are not evidence of authenticated live backend behavior or a device deployment.
The final analyzer check of all touched UI files and tests passed with no issues.

Run:

```sh
flutter test test/hospitality_ui_test.dart test/credential_form_test.dart
```

Set `VW_UI_PREVIEW_DIR` to an output directory to export the light/dark dashboard
previews while running those tests.
