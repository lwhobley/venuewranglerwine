# Venue Wrangler

Operations command for wine-led hospitality, built with Flutter and Supabase.

Modules: tenant and roles, opening cellar, offline counts, stock movement, allocations, service, host stand, people, business reporting, workforce scheduling and attendance (with clock-in geofencing), interactive floor plan, data import, and a POS gateway (Square pull; webhook and push for other providers).

Architecture: `docs/architecture/`. Phase notes: `docs/phases/`. iOS release: `docs/codemagic-ios.md`.

```
supabase start
flutter run -d chrome --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=<anon key> --dart-define=REQUIRE_EMAIL_VERIFICATION=false
flutter analyze
flutter test
```

Without the Supabase defines, the app stays on the configuration screen. It does not invent a session.

Release builds must be compiled with `SUPABASE_URL` and `SUPABASE_ANON_KEY`; the Codemagic workflow fails if the Supabase host is not present in the built app.

Edge functions: `deno test --no-check supabase/functions/pos-gateway/`. Optional `FCM_PROJECT_ID` overrides the Firebase project checked by `workforce-push`.
