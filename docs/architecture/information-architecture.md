# Information architecture and route map

Venue Wrangler is an operations command platform. The tenant root is an organization. Venues, storage, staff, guests, and wine inventory hang from that organization. A person never sees another tenant's data.

Navigation is role-aware. Phase 1 ships only the routes that have a real workflow. Later modules are not present as empty tabs.

## Tenant context

Organization → Venue → Area / outlet → Storage location

The active organization and venue sit in the workspace header. Time is stored in UTC and rendered in the venue timezone.

## Primary areas

| Area | Who | Purpose |
| --- | --- | --- |
| Tonight | Every signed-in member | What needs attention now |
| Wine | Beverage director, counter, bartender, GM | Cellar, counts, receiving, service |
| Floor | Host, floor manager, GM | Reservations, floor board, guests |
| People | Scheduler, GM, owner | Team, schedule, time clock |
| Events | Event manager, GM | Holds, BEOs, event-day command |
| Execution | Department leads | Checklists, logbook, documents, inbox |
| Business | Owner, GM, auditor | Sales, reports, integrations, billing, settings |

Wine is not a bar-stock category. It has its own navigation because location, lot, ownership, and service readiness are first-class.

## Route map

```
/setup
/sign-in
/sign-up
/reset-password
/verify-email
/auth/recovery
/onboarding/organization
/onboarding/venue
/onboarding/join
/invite?token=

/app/home
/app/team
/app/profile

/app/cellar
/app/cellar/import
/app/cellar/receive
/app/cellar/move
/app/cellar/allocations
/app/cellar/service
/app/cellar/counts
/app/cellar/counts/:id
/app/cellar/counts/:id/review

# later phases, not linked until the workflow exists
/app/wine
/app/wine/map
/app/wine/catalog
/app/wine/catalog/:id
/app/wine/counts
/app/wine/counts/:id
/app/wine/receiving
/app/wine/movements
/app/wine/purchasing
/app/wine/allocations
/app/wine/service
/app/wine/lists
/app/wine/reports
/app/wine/config
/app/reservations
/app/floor
/app/guests
/app/guests/:id
/app/schedule
/app/clock
/app/events
/app/events/:id
/app/checklists
/app/logbook
/app/documents
/app/inbox
/app/sales
/app/reports
/app/integrations
/app/billing
/app/settings
```

## Guard rules

1. Missing Supabase configuration stays on `/setup`. There is no local fake session.
2. Signed-out users can only reach sign-in, sign-up, and password reset.
3. Unverified email stays on `/verify-email`.
4. A password-recovery session can only set a new password.
5. A signed-in user with no membership goes to organization creation, join-by-code, or invite acceptance.
6. After organization creation, the entry gate sends an owner with no venue to venue setup.
7. Membership loading does not redirect. The current screen shows a loading or retry state.

Client guards are for navigation only. Postgres RLS and security-definer functions decide what a request can do.
