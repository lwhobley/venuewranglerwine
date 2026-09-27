# Screen specifications

These are the operational screens for the wine and host slices. They are not in the Phase 1 navigation. Phase 1 screens are listed in `docs/phases/phase-1.md`.

Shared states for every screen: loading skeleton, empty state with one next action, offline banner with last sync time, permission denied without a disabled control that looks tappable, inline validation, and a success or failure line that names the record.

## Wine Overview

User: beverage director, GM.

Desktop: left rail, command header with venue and sync, then a single column of operational lines rather than a card grid. Mobile: the same lines, stacked, with the sync chip pinned.

Lines, in order: bottles and cases on hand; on-hand value and retail value (hidden without `wine.cost.read`); stock by zone; low and out of stock; receiving not put away; unapproved adjustments; uncounted locations; 86'd wines; allocation demand versus available; recent movements.

Empty: "Receive the first delivery" if the catalog has items, otherwise "Import the wine catalog".

## Cellar Map

User: beverage director on tablet or desktop; counter on mobile uses the location navigator, not a shrunk canvas.

Canvas: drag, resize, rotate, and label storage units. Inside a unit, addressable slots. Toggles: occupancy, capacity, type, region, vintage, ownership, value, count status, exception. Search a wine and highlight every slot that holds it. Search a location code and focus it.

Saving a layout creates a version. Removing a slot that still has quantity is blocked until the operator maps those bottles to another slot.

Mobile: breadcrumb, QR scan, list of units, capacity bar. No canvas.

## Count Mode

User: inventory counter. Reviewer is a different screen.

Session header: scope, mode (blind or expected), offline state, last sync. Scan location QR, then scan or search the wine. Increment and decrement are at least 44px. Expected quantity is absent in blind mode. Each entry stores location, item, lot if known, quantity, format, note, and photo reference locally before sync.

Conflict: if another counter posted the same location since the freeze, the entry stays unposted and the reviewer sees both quantities. Approval writes an adjustment. The original count remains.

## Receiving

User: beverage director or GM with `wine.receive`.

PO lines, then receive by scan, SKU, or catalog match. Partial, damaged, and substitution are explicit line states. Landed cost is allocated in numeric, not float. Receipt lands in a staging location. Put-away is a separate movement into mapped slots. Invoice photo is attached; OCR may suggest lines later, but a person confirms before post.

## Movement

User: bartender or beverage director with `wine.movement.write`.

Source location, wine, quantity, destination, reason. Available quantity is checked before post. Reasons include service bar, event staging, member locker, tasting, breakage, comp, and return to vendor. Success shows before and after quantities and the ledger id. Failure leaves the form intact.

## Allocation

User: club manager with `wine.allocation.manage`.

Campaign: release date, tier, wines, quantity, substitution rule, pickup or ship. A readiness line shows required, on hand, already allocated, and incoming. Reserving writes a hold that reduces available-to-sell without removing physical on hand. Fulfillment moves the hold to a pickup or locker and writes the ledger. The same bottles cannot be reserved twice; the function rejects the second hold.

## Host Dashboard

User: host. Managers see the same board plus section and pacing controls.

Daybook of reservations, waitlist, and walk-ins. Quick actions: seat, cancel, no-show, note. Guest panel shows allergies, seating preference, VIP, and favorite wines. Favorite wines link to cellar location and 86 state, read-only unless the host also has a wine permission. Floor assignment uses the live floor, not a separate guest list.

Empty service: "Add today's first reservation." Offline: the board shows the last synced book and blocks seating until sync returns, because a seat is a shared state.
