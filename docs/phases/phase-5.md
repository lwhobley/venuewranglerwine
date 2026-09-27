# Phase 5 — allocation

## Architecture note

House quantity is what a transfer or a new release can take. Reserving a campaign moves bottles from `house` to `allocated` on the same slot and lot, and writes an `allocation_reserve` movement. A second release or a bar transfer only reads `house`, so those bottles cannot be promised twice.

Lines are reserved in id order. If two members want the same wine and the cellar is short, the later line shows the shortage and receives only what remains. Pickup moves the hold from `allocated` to `member` and writes an `allocation_pickup` movement plus a fulfillment record. Pickup cannot exceed the reserved remainder.

## Completed screens and flows

- Add a club member with a tier.
- Create a release and add member lines.
- See required, reserved, and shortage, including a shortage caused by an earlier line on the same wine.
- Reserve available bottles.
- Record member pickup against the reserved quantity.

## Tests

Shared-house shortage, pickup ceiling, and a SQL contract that reservation is a function and lines are not client-insertable.

## Known limitations

- Members are allocation names, not the guest CRM. Consent, tenure, and communication stay for a later guest module.
- Pickup does not move the bottle into a locker location. It changes ownership on the current slot. A locker transfer can follow with the phase 4 move, but that move still only sees house stock, so a member-held bottle is not transferable that way.
- Counts still freeze house quantity, so allocated bottles are not on the count sheet.
- RLS was reviewed as SQL. It has not been executed against a live database in this environment.
