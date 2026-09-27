# Phase 3 — inventory count

## Architecture note

A count session freezes expected quantity from current slot balances. The counter does not write those numbers. Entries are saved on the device first, then posted with a client entry id so a retry does not create a second line.

Blind mode omits expected quantity from `count_sheet` unless the caller can review or approve. The column is not granted on the line table.

Approval writes a `count_adjustment` movement for each counted line whose quantity differs from the freeze. The adjustment is `current + (counted - expected)`, so stock received after the freeze is not erased. The original count line stays. A variance that would take a balance below zero is rejected. A found bottle with no lot cannot be approved until it is received.

If two counters enter different quantities for the same slot, the second entry is stored as a conflict and does not overwrite the first. Approval is blocked until a reviewer resolves it.

## Completed screens and flows

- Start a full, partial, cycle, spot, opening, closing, event-prep, or audit count, blind or expected.
- Enter a location code, or paste the `vw:loc:` payload a slot label would carry.
- Search a wine by SKU or name, set a bottle quantity, and save it on the device.
- Sync when the connection returns. The screen shows the last sync time and unsynced entries.
- Submit the count.
- Review expected, counted, and conflicts. Approve posts adjustments. Reject posts none.

## Tests

Variance math, blind visibility, location payload parsing, local draft persistence, and a SQL contract that approval is a movement and count lines are not client-insertable.

## Known limitations

- The camera scanner package is not linked. The count field accepts the same location code a QR label encodes, including a wedge scan or paste. Camera capture is the next increment.
- Drift is still not the store. Count drafts use the same on-device queue as invites so web counts work without a WASM sqlite build.
- Uncounted lines are not treated as zero. Only lines with a counted quantity can adjust stock.
- RLS was reviewed as SQL. It has not been executed against a live database in this environment.
