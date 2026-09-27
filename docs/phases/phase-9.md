# Phase 9 — events and business

An event moves inquiry, hold, booked, live, closed, one stage at a time. Each BEO save is a new version. The floor channel accepts a message. A generic POS connection can be marked without calling a vendor or storing a secret. Reports export as CSV only when the organization has a trial or active plan that includes `reports`.

Known limitation: checkout, email, and live vendor sync are not connected. Plan changes are not a client action. A verified billing webhook must call `set_plan` as the database owner.
