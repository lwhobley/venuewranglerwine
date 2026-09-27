# Phase 4 — movement

## Architecture note

Reserve stock lives on a mapped slot. A transfer checks that lot's house quantity in that slot, then writes one append-only movement. The source balance falls and the destination balance rises by the same quantity. The lot total does not change, because the bottles stayed in the venue.

Destination kind chooses the ledger reason: `transfer_service`, `transfer_event`, or `transfer_locker`. A locker requires a member name. Creating a destination requires catalog write. Moving into one requires movement write, so a bartender can transfer to a bar they did not create.

The function returns the before and after quantities. That is the chain of custody for the move.

## Completed screens and flows

- Add a service bar, event hold, or member locker.
- Choose a lot sitting in a mapped slot.
- Transfer whole bottles only if that slot has them.
- See the source before and after, and the destination after.
- Read the recent transfer ledger.

## Tests

Availability, whole-bottle, locker holder, and a SQL contract that the transfer is a function rather than a client insert.

## Known limitations

- Member lockers are named locations, not club-membership records. Allocation and double-hold prevention are phase 5.
- Transfers are online. An offline move could double-spend a slot, so it is not queued.
- The movement does not yet link to an event id or a member id. Those foreign keys arrive with events and allocations.
- RLS was reviewed as SQL. It has not been executed against a live database in this environment.
