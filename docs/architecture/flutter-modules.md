# Flutter module plan

One codebase for iOS, Android, web, and desktop. Feature folders own presentation, application, and domain. Supabase adapters live in `data` and are not imported by widgets.

```
lib/
  app/            bootstrap, router, theme
  core/           auth, permissions, money, time, errors, offline, networking
  features/
    onboarding/   auth, organization, venue, invite, join
    dashboard/    tonight shell
    staff/        directory, skills, wages          phase 8
    scheduling/                                     phase 8
    time_clock/                                     phase 8
    guests/                                         phase 7
    reservations/                                   phase 7
    floor_plan/                                     phase 7
    events/                                         phase 9
    checklists/                                     phase 8
    logbook/                                        phase 8
    documents/                                      phase 8
    chat/                                           phase 9
    sales/                                          phase 9
    reports/                                        phase 9
    integrations/                                   phase 9
    billing/                                        phase 9
    settings/                                       phase 9
    wine_inventory/
      catalog/                                      phase 2
      cellar_map/                                   phase 2
      locations/                                    phase 2
      counts/                                       phase 3
      receiving/                                    phase 2
      movements/                                    phase 4
      purchasing/                                   phase 2
      allocations/                                  phase 5
      wine_lists/                                   phase 6
      reports/                                      phase 6
```

## Rules

- Widgets call application controllers. Controllers call repository interfaces.
- Permission checks in the client hide actions. The server still rejects them.
- Money and quantities use `DecimalAmount`. No `double` for cost, price, or stock.
- Timestamps are UTC. `VenueClock` renders them in the venue IANA zone.
- Writes that can be retried go through `MutationQueue`. Invites already do. Counts will.
- Dio is the HTTP client for future edge functions, with retry only for idempotent calls. Supabase Auth and PostgREST stay on the Supabase client.
- Telemetry is a `Telemetry` interface. Without a DSN it does not pretend to ship events.

## State and navigation

Riverpod notifiers hold auth, tenant session, and workspace selection. `go_router` refreshes from those notifiers. Redirect logic is a pure function in `lib/app/redirect.dart` so it can be tested without a widget tree.

## What is actually linked

`onboarding`, Tonight, Team, Profile, and Cellar (`wine_inventory`). Floor, schedule, and events are not stubbed in the nav.
