-- 0012_one_active_booking_per_tenant.sql
-- Enforce: a tenant can only have ONE active (reserved/occupied) booking at a time.
-- Also cleans up George Trial's duplicate booking (the cheaper 200,000 room).

-- ── Step 1: Delete the cheaper duplicate booking for George Trial ──────────
-- Keep the booking with the HIGHER rent_amount per tenant, delete the rest
-- that are in 'reserved' or 'occupied' status (active).
DELETE FROM bookings
WHERE id IN (
  SELECT id FROM (
    SELECT
      id,
      tenant_id,
      rent_amount,
      reserved_at,
      ROW_NUMBER() OVER (
        PARTITION BY tenant_id
        ORDER BY rent_amount DESC, reserved_at DESC NULLS LAST
      ) AS rn
    FROM bookings
    WHERE status IN ('reserved', 'occupied')
  ) ranked
  WHERE rn > 1  -- delete all except the #1 (highest rent) per tenant
);

-- ── Step 2: Restore properties whose only booking was just deleted ─────────
-- If a property's booking was deleted, it should become 'live' again
UPDATE properties
SET status = 'live'
WHERE status = 'reserved'
  AND id NOT IN (
    SELECT DISTINCT property_id FROM bookings
    WHERE status IN ('reserved', 'occupied')
  );

-- ── Step 3: Add a partial unique index ────────────────────────────────────
-- This is a more powerful constraint than a simple UNIQUE column:
-- It prevents any tenant from having more than one row where
-- status is 'reserved' OR 'occupied' at the same time.
-- (A regular UNIQUE constraint can't do this because it covers ALL rows.)
DROP INDEX IF EXISTS bookings_one_active_per_tenant;

CREATE UNIQUE INDEX bookings_one_active_per_tenant
  ON bookings (tenant_id)
  WHERE status IN ('reserved', 'occupied');

-- Now if the app tries to insert a second active booking for the same tenant,
-- the database will throw a unique constraint violation, preventing it entirely.
