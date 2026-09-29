# Workforce implementation and verification

The scheduling brief extends the existing People workflow, shifts and time entries. Existing schedules and import functionality must remain compatible.

## Scope

- Schedule Board: responsive employee/role views, day/week/two-week/month range, filters, drag/drop plus keyboard-accessible move/assign controls, editable draft and published shifts, publication, retraction, copying, staffing requirements and version history.
- Staff: personal schedule, instructions, open shifts, drop/pickup/swap requests with recipient acceptance and manager approval, recurring/one-time availability and time off.
- Management: department/job-role directory, staff employment and qualifications, certification evidence, protected effective wage rates, templates, labor targets/forecasts, coverage, reports, settings.
- Attendance: assigned or authorized unscheduled work, clock in/out, paid/unpaid breaks, missed-break attestations, reviewed offline captures and auditable corrections.
- Infrastructure: tenant-safe server commands and RLS, command idempotency and revision conflicts, immutable audit history, UTC storage and explicit DST resolution, typed models, scoped SQLite drafts/cache, Realtime, private certification storage, notifications and CI.

## Decisions

- Managers may change a published shift only with an explicit confirmation; changes remain published and notify affected staff. Retraction is a separate permission and operation.
- Staff retain responsibility for released/swapped shifts until the server approves the request. Eligibility is rechecked at approval, including venue membership, role, required certifications, overlapping assignments, availability, rest and hours.
- Mandatory certification and venue authorization cannot be overridden. A permitted manager may document an override of availability/rest/hour conflicts.
- Offline scheduling edits preserve the expected revision and must be reviewed/synced. Offline clock events are attestations awaiting manager review, never silently trusted as server clock timestamps.
- Monetary values remain decimal strings in application models and PostgreSQL numeric values on the server. Reports show missing wage rates explicitly.
- Firebase project `venuewranglerwine` has a registered Android app and validated `android/app/google-services.json`. Remote delivery additionally requires server credentials; verify activation with an actual delivery before claiming push works.

## Verification gates

1. Schema and permissions: migration replay, tenant isolation, wage protection, blocked direct writes and staff self-scope.
2. Commands: stale revisions, idempotency, concurrent claims, approval eligibility, copies, publication/retraction, time-off conflicts, break/correction history.
3. Time and cost: overnight intervals, DST gaps/folds, overtime, unpaid breaks and decimal arithmetic.
4. Flutter: generated models, repository/offline/widget tests, responsive accessibility, analyze and full regression suite.
5. Android: release build, install and importer/workforce smoke tests on the connected phone once unlocked.

The workforce implementation and database migration are installed. Android smoke checks passed; remote push delivery remains unverified.

## Current implementation

Open **People → Open scheduling & time clock**. The 12 workspaces share authenticated venue selection. The board supports day/week/two-week/month ranges, employee/role lanes, department/job/area/event/employee filters, drag-to-move, drag-roster-to-assign, and keyboard-accessible editing. Overnight shifts occupy each relevant day.

Start in Team Directory: invite people through Team, add profiles linked to their accounts, create job roles, and approve roles/skills/certifications. Create a draft schedule period, add shifts and assignments, then publish. The server checks qualifications, tenant authorization, overlaps, approved leave, rest, availability, and weekly limits. Documented manager overrides resolve soft conflicts; mandatory skills/certifications and venue access remain hard requirements.

Staff can request release/pickup/swap, accept incoming swaps, set availability, request leave, message the team, and clock work/breaks. Pending releases retain responsibility. Offline clock captures remain claims for review; managers apply accepted claims through separately audited corrections.

Templates, requirements, protected wage rates, targets, forecasts, CSV export, and planned/actual labor calculations are connected. Server reports split overnight intervals by local date and calculate weekly overtime across the organization's venues. Wage snapshots and financial audit payloads are omitted from offline caches.

The atomic migration is deployed as `20260928094804_workforce_management.sql` to Supabase project `aqhxbvaeuenqoljwwfcw`. Staged migrations were consolidated to avoid duplicate application. `tool/export_role_catalog.dart` emits a reference catalog; future permission changes need a new migration.

Live rollback fixtures passed commands, exchanges, attendance, copies/templates, DST rejection, exact numeric serialization, direct-write denial, outsider isolation, employee wage isolation, and department scope. The final full Flutter suite passed all 79 tests, including a concrete drag gesture. Fixture business data and users were rolled back.

After the workforce deployment, the importer regression passed all 16 datasets, metadata updates, replay protection, atomic rollback, parent isolation, cycles, field validation, and permissions. Final Flutter analysis found no issues.

The updated Android release APK built successfully and was installed on device `C67202411042663`. The final app process started without Flutter or Android runtime errors in its scoped log. Authenticated scheduling opened in the tester venue, all 12 workspaces appeared in the menu, Team Directory and Time Clock empty states loaded, and an empty department save displayed required-field validation. A navigation issue discovered on the phone was fixed and the corrected APK reinstalled: People remains selected inside scheduling. Android notification permission was granted and the server confirmed one active registered Android device for the account. No test staff records or clock punches were created in the tester venue. Populated scheduling and importer device flows still require end-to-end device verification; server fixtures passed separately. Final APK SHA-256: `B1DD7D7C5DA2A9817C41872D4023E16A14CD93F7BAD606EB67C9F559BC924003`.

The web release build and Wasm dry run passed before the final shared navigation selection correction. The generated web output contains the pinned SQLite Wasm and Drift worker assets. Browser runtime and web push delivery were not tested.

## Push activation

Venue clock-in and clock-out now require a configured address-based geofence,
with a maximum radius of 1,000 feet. See [clock geofence](clock-geofence.md) for
setup, enforcement and verification boundaries.

Android initialization, device registration, foreground notices, deep links, and local reminders are implemented. Enable notifications from My Schedule or Scheduling Settings. The deployed `workforce-push` function rejects calls while its job secret is absent.

Activation requires Edge Function secrets `FCM_SERVICE_ACCOUNT_JSON` for a messaging-only service account in Firebase project `venuewranglerwine`, and random `WORKFORCE_PUSH_JOB_SECRET`. Invoke the worker via POST with that job bearer secret from a private scheduled job. Database claim functions are limited to `service_role`; employees cannot send arbitrary pushes. Retries use stable collapse identifiers. Provider acceptance is not proof of a phone notification; verify real device delivery.

APNs/iOS configuration and web FCM registration have not been supplied. Those push channels remain unconfigured; in-app notices remain available. Browser SQLite assets are pinned to Drift 2.35.0. Serve `sqlite3.wasm` as `application/wasm`.

## Reproduction

- `flutter analyze --no-pub`
- `flutter test --no-pub`
- Local Supabase integration: `psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f tool/verify_workforce.sql`; fixtures roll back.
- Android: `flutter build apk --release --no-pub --dart-define-from-file=.env`, with Java 17.

CI includes formatting, analysis, tests, local migration replay/integration, and Android release builds. Local Docker did not respond, so migration replay was verified in a rollback transaction on the configured Supabase project. Gradle now uses a 3 GB heap and two workers to fit this 8 GB computer.
