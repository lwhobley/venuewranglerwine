# Phased implementation plan

Each phase is a runnable slice: migrations, RLS, seed or catalog data, tests, and the screens that flow actually uses.

| Phase | Outcome | Done when |
| --- | --- | --- |
| 1 | Auth, organization, venue, roles, invites, join approval, RLS | A new owner can sign up, create a wine-club venue, invite a role no higher than their own, and an invitee can accept only from the invited email |
| 2 | Opening cellar | Rooms, rack templates, mapped slots, vendor, wine import, first receiving into a staging location, then put-away |
| 3 | Count | QR location, scan or search wine, offline entries, variance review, approved adjustment, audit history |
| 4 | Movement | Reserve to bar, event, or member locker with a ledger row and availability checks |
| 5 | Allocation | Release, reserve stock, shortage view, member pickup that cannot double-allocate |
| 6 | Service | List availability, open bottle, pour depletion, 86 |
| 7 | Host stand | Reservations, guest preferences including favorite wines, live floor seating |
| 8 | People and execution | Schedules, time clock, checklists, logbook, documents |
| 9 | Events, chat, reports, integrations, billing | BEO command, channels, exports, provider-neutral connectors, plan entitlements |

Deferred on purpose until a provider is chosen: email/SMS delivery, POS depletion import, invoice OCR, push notification transport, and subscription checkout. The interfaces are named in the schema design. They are not fake-connected.

Phases 1 to 9 are implemented. See `docs/phases/`.
