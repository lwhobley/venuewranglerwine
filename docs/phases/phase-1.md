# Phase 1 — tenant, auth, and roles

## Architecture note

Auth is Supabase Auth. Organization, venue, invite, join, and role changes are Postgres functions that run as the table owner and check `auth.uid()` plus the permission matrix. The Flutter client uses the same matrix only to show or hide actions. Riverpod holds the session. `go_router` calls `resolveRedirect`.

Invites that fail on the network are stored in a device queue and retried with the same token. The token is shown once, after the server accepts it. It is stored only as a hash.

Money is a decimal type even though Phase 1 has no prices yet, so later wine cost cannot slip in as a float. Venue time uses IANA zones.

## Completed screens and flows

- Sign up, sign in, sign out, password reset request, recovery password update, email verification hold
- Create organization (caller becomes organization owner)
- Create opening venue with timezone, currency, and service style
- Invite, revoke, and accept, including email match and rank ceiling
- Join by venue code, manager approve or decline
- Change an existing member's role, with last-owner protection
- Tonight: venue local time, join code for people who can invite, audit activity, queued-invite retry
- Team and profile
- Configuration gate when `SUPABASE_URL` or `SUPABASE_ANON_KEY` is missing

## Tests

`flutter test` covers password and slug rules, role rank, permission overrides, decimal math, venue timezone formatting, redirect guards, the RLS migration contract, and the role-catalog drift check.

## Known limitations

- Invite and reset emails are not sent by this app. Local Supabase mail is Inbucket. The inviter copies the one-time code.
- Notification preferences, device session lists, and push are not built. There is no fake inbox.
- Drift/SQLite is not the Phase 1 store. The count workflow is the offline-critical path and will use Drift. Phase 1 queues invites in `shared_preferences`, which works on web without a WASM sqlite build.
- Sentry is an interface only. No events are sent until a DSN and the SDK are added.
- Wine, floor, schedule, events, and billing routes are specified and not linked. Opening them would be a placeholder.
- RLS has been reviewed as SQL and locked to the client matrix by test. It has not been executed against a live database in this environment.

## Run

```
supabase start
flutter run -d chrome --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=<anon key from supabase status> --dart-define=REQUIRE_EMAIL_VERIFICATION=false
```
