# Phase 6 — service

## Architecture note

A list item is available only when the list is published, it is not manually 86'd, and either house bottles meet the threshold or an open bottle can still cover the pour. Allocated and member-held bottles are not counted. Opening a bottle takes one house bottle and writes a `service_open` movement. Pours reduce that open bottle and write a depletion row. They do not touch allocated stock.

## Completed screens and flows

- Create a by-the-glass list and add a wine with a pour size.
- Publish or unpublish the list.
- Manually 86 a wine, or clear the 86.
- Open one house bottle.
- Pour a glass until the bottle is finished.
- See available versus 86, with the reason.

## Tests

Open-bottle availability, manual 86, pour ceiling, and a SQL contract that opening consumes house stock through a function.

## Known limitations

- POS sales are not connected. Pours are entered here until an adapter exists.
- The service screen creates one glass list. Bottle, reserve, member, and event lists are accepted by the database and not given separate editors.
- Camera scan is still not linked.
- RLS was reviewed as SQL. It has not been executed against a live database in this environment.
