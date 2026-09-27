# Schema and RLS

Tenant isolation is `organization_id` on every business row, plus RLS. The API roles `anon` and `authenticated` are not table owners, so RLS applies to them. Security-definer functions run as the owner and are the only write path for membership, invites, and venues. Do not `FORCE ROW LEVEL SECURITY`, or those functions would be blocked by the same policies.

Phase 1 tables and policies are in `supabase/migrations/20260927000000_phase1_tenant_auth.sql`. The role and permission catalog is in `20260927000100_role_catalog.sql` so hosted projects get the same matrix as the client. A Dart test fails if those two drift.

## Phase 1 tables

`profiles`, `organizations`, `venues`, `app_roles`, `permissions`, `role_permissions`, `memberships`, `membership_permission_overrides`, `invites`, `join_requests`, `platform_admins`, `audit_events`.

`platform_admins` has RLS and no client policies. Platform owner is not an organization role. Organization owner is created inside `create_organization`, not by a client insert.

Helpers, all `security definer` with `search_path = ''`:

- `is_org_member(org)`
- `has_permission(org, permission)`
- `has_scoped_permission(org, venue, permission)`
- `actor_can_grant(org, venue, role, permission)` — caller rank must be less or equal privilege, and the caller must hold the named permission. Venue-scoped membership cannot grant an organization-wide role.

Invite tokens are hashed with SHA-256 before storage. Accept compares the hash and the signed-in email. Join codes are not selected by clients; `venue_join_code` returns one only when the caller can invite or update that venue.

`audit_events` rejects update and delete. Clients have no insert grant.

## Wine ledger

Phase 2 migrates the opening-cellar tables in `supabase/migrations/20260927000200_phase2_cellar.sql`. Every row carries `organization_id`. Quantity is `numeric(14,3)`. Money is `numeric(14,4)`. No float columns. Count, allocation, and service tables are still designed only.

| Table | Role |
| --- | --- |
| `inventory_items`, `wine_profiles`, `barcodes`, `inventory_images` | Master data. Vintage may be null for non-vintage. |
| `inventory_lots` | Vendor, PO, landed cost, received, depleted, damaged, allocated, on hand |
| `storage_locations`, `storage_units`, `storage_slots`, `cellar_map_versions`, `cellar_map_objects` | Location codes such as `CELLAR-A/RACK-03/SIDE-A/ROW-05/BIN-12`. Map edits create a version. Slots are not deleted out from under a balance; a migration maps old slot to new slot. |
| `inventory_movements` | Append-only ledger: before, after, user, reason, lot, source, destination, linked PO, count, event, or allocation |
| `inventory_balances` | Materialized current quantity by org, venue, location, item, lot, ownership class. Rebuilt from the ledger. |
| `inventory_count_sessions`, `inventory_count_scopes`, `inventory_count_entries`, `inventory_adjustments` | Expected quantity frozen at session start. Approval writes an adjustment movement. It does not overwrite the count. |
| `vendors`, `purchase_orders`, `purchase_order_lines`, `receipts`, `receipt_lines` | Receiving lands in staging, then a put-away movement. |
| `wine_lists`, `wine_list_items`, `service_depletions`, `open_bottles` | Availability and pour ledger. |
| `wine_club_memberships`, `allocation_campaigns`, `allocation_lines`, `member_holding_records`, `fulfillment_records` | Physical on hand, available to sell, and allocated are separate quantities. |

Balance rule: a movement that would make quantity negative is rejected unless the actor holds a privileged adjustment permission and the movement reason is `privileged_adjustment`. Cost reports require `wine.cost.read` or `report.financial`. Other wine roles can see quantity without cost.

RLS for the ledger uses the same helpers: select requires org membership and the matching read permission; insert of a movement is a function, not a table grant, so a client cannot write a balance directly.

Indexes for the ledger, when migrated: `(organization_id, venue_id, storage_slot_id)`, `(organization_id, inventory_item_id)`, `(organization_id, lot_id)`, and a GIN full-text index on producer, cuvée, and location code.
