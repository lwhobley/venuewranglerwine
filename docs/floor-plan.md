# Host floor plans

Open **Host → New room** to begin with a blank canvas. Add tables, chairs, walls, doors and section labels by tapping or dragging the palette. Select furniture to change its label, size, rotation, capacity, accessibility, section or server. Zoom and pan the canvas; use Undo/Redo before saving. Imported tables begin unplaced and can be placed into a room.

## Picture or diagram

**Picture / PDF** accepts PNG, JPEG, WebP or a selected PDF page. The app creates a bounded PNG reference and stores it in private venue storage. Uploads automatically attempt table detection. **Detect tables** repeats detection on an existing reference.

Detection proposes contrasting outlines or surfaces. Android and iOS additionally attempt OCR for table numbers. Review every proposal, uncheck mistaken fixtures, and edit labels and seat counts. Seat counts default to four and are not inferred. Accepted proposals remain unsaved editable furniture. Move, resize or rotate them before **Save layout**. **Adjust reference** changes the image position, size, rotation and opacity. If detection finds nothing, trace the image with the palette. Diagrams with separated table outlines work best; photographs, touching furniture and complex backgrounds can require manual correction. Web and desktop currently use geometry detection without native OCR.

## Seating

Select clean, unassigned tables in one room and **Combine** to create a seating unit with summed capacity. **Separate** restores individual units. Active assignments must be cleared before changing combinations. Assign servers and update clean/ready, held, seated, dirty, cleaning or blocked states. Occupied tables cannot be marked clean.

Create reservations or walk-ins, record party size, allergy notes, accessibility, high-chair needs, preferred section, quoted wait and expected duration. Select an eligible table or combination to assign or seat the party. Arrival, transfer, completion, cancellation and no-show actions retain guest history. Transfers and completed parties leave vacated tables dirty. Venue time zones are used for bookings, including explicit handling of daylight-saving gaps and ambiguous times.

## Persistence and access

Floor mutations use permission-checked RPCs scoped to the organization and venue. Commands serialize by venue, carry idempotency keys and check revisions. Capacity, occupancy and overlapping reservations are enforced on the server. Table imports share the same venue lock and revision/capacity checks. Realtime updates refresh service views while local editor drafts remain intact; stale drafts must be refreshed before saving. Reference images use private, append-only paths and temporary signed URLs.

## Verification

- `test/floor_plan_test.dart`: blank layouts, group capacity, availability, accessibility, booking windows, exclusive occupancy, dragging, vertical and diagonal movement inside a scrolling page, phone canvas, validation, time zones and image normalization.
- `test/floor_detection_test.dart`: rectangle/circle proposals, rejection of walls and tiny text, blank images, filled squares, PNG decoding and isolate execution.
- `supabase/tests/floor_plan_test.sql`: rollback-only checks for saved layouts, replay, stale revisions, combinations, transfers, cleaning, booking conflicts, import capacity, denied direct writes and venue isolation. Passed against the configured Supabase project.

Android 14 device checks confirmed a blank initial floor, PNG and PDF uploads, three table proposals with a round table and recognized table numbers, an editable capacity changed from four to six, accepted proposals in the editor, and the discard confirmation. A vertical-drag issue found during that check was corrected and covered by the scrolling-page regression. Both Android builds succeeded. The corrected build passed all 15 floor tests and its focused analyzer check. Installation was initially blocked by an automatic approval review usage limit; after that reset, the retry found the phone disconnected. Installation of the corrected APK and the final phone drag check remain pending. The last verified phone state was the unsaved-draft discard confirmation; no test furniture was saved to the venue.

Live SQL verification does not substitute for local database CI. Local database CI was not run in this session.
