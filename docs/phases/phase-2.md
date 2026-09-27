# Phase 2 — opening cellar

## Architecture note

Cellar writes go through security-definer functions. A client can read locations, slots, wines, and quantities. It cannot insert a movement or a balance. Unit cost columns are not granted to the API role. Quantity and money columns are `numeric`.

Placing a rack writes a map version and one slot per template cell. Location codes look like `CELLAR-A/RACK-01/SIDE-A/ROW-05/BIN-12`. There is no delete path for a slot, so a later redesign cannot drop a location that still has a balance.

Receiving creates a purchase order, a receipt, a lot, a staging balance, and a `receive` movement. Put-away moves that quantity onto a slot and writes a `put_away` movement. It refuses a quantity the staging location does not hold, a fractional bottle, or a slot that would exceed capacity.

Import is idempotent on organization plus SKU. A repeat import updates the profile and does not change on-hand quantity. Invalid rows are returned; valid rows still import.

## Completed screens and flows

- Add a cellar room. The first room also creates the staging location.
- Place a bin rack, shelf, case stack, or fridge from a stored template.
- See every generated slot and its occupancy.
- Import a CSV, including the opening sample, with a preview of rejected rows.
- Add a vendor.
- Receive whole bottles into staging.
- Put those bottles away into a mapped slot.

Cellar is in the navigation only when the membership can read the wine catalog. Receive, vendor, and rack placement stay hidden without the matching permission.

## Tests

Location codes, CSV duplicates and quoted commas, put-away capacity, and a SQL contract that the new tables have RLS, numeric money, and no client insert on the movement ledger.

## Known limitations

- The map is a slot grid, not a drag canvas. Multi-side racks are always side A until the canvas editor exists.
- Rack redesign is not offered. Adding a rack is safe. Removing one is not implemented, on purpose.
- Invoice OCR, barcode scanning, and partial-bottle receiving are later phases.
- Cost is stored and withheld from the list API. A cost report is not on this screen.
- RLS was reviewed as SQL. It has not been executed against a live database in this environment.
