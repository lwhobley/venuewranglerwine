# Venue Wrangler

Operations command for wine-led hospitality. Phase 1 is authentication and tenant roles. Phase 2 is the opening cellar. Phase 3 is offline counts. Phase 4 transfers reserve stock. Phase 5 reserves a release. Phases 1–9 are implemented: tenant, cellar, counts, movement, allocation, service, host stand, people, and business.

Architecture: `docs/architecture/`. Phase note: `docs/phases/phase-1.md`.

```
supabase start
flutter run -d chrome --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=<anon key> --dart-define=REQUIRE_EMAIL_VERIFICATION=false
flutter analyze
flutter test
```

Without the Supabase defines, the app stays on the configuration screen. It does not invent a session.
