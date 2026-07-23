-- 0013_booking_trigger_update_property_status.sql
--
-- PROBLEM: Tenants cannot update the 'properties' table directly due to RLS.
-- When a booking is inserted, the app tried to do:
--   UPDATE properties SET status = 'reserved' WHERE id = ?
-- But this was silently blocked by RLS, leaving the property as 'live'.
--
-- SOLUTION: A SECURITY DEFINER trigger runs as the DB owner (bypasses RLS).
-- Whenever a booking row is inserted with status='reserved' or updated to
-- 'reserved'/'occupied', the trigger automatically flips the property status.
-- When a booking is cancelled/terminated, it flips back to 'live'.

-- ── Step 1: Create the trigger function (runs as superuser, bypasses RLS) ──

CREATE OR REPLACE FUNCTION fn_sync_property_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER  -- runs with DB owner privileges → bypasses RLS
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    IF NEW.status IN ('reserved', 'occupied') THEN
      -- Mark the property as reserved/taken
      UPDATE properties
        SET status = NEW.status
        WHERE id = NEW.property_id;
    ELSIF NEW.status IN ('completed', 'cancelled', 'terminated') THEN
      -- Release the property back to live so it appears in Explore again
      UPDATE properties
        SET status = 'live'
        WHERE id = NEW.property_id;
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN
    -- If booking row deleted entirely, restore the property
    UPDATE properties
      SET status = 'live'
      WHERE id = OLD.property_id;
  END IF;

  RETURN NEW;
END;
$$;

-- ── Step 2: Attach the trigger to the bookings table ──────────────────────

DROP TRIGGER IF EXISTS trg_sync_property_status ON bookings;

CREATE TRIGGER trg_sync_property_status
  AFTER INSERT OR UPDATE OR DELETE ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION fn_sync_property_status();

-- ── Step 3: Fix data RIGHT NOW ─────────────────────────────────────────────
-- Update any property whose booking is active but property is still 'live'
UPDATE properties
SET status = 'reserved'
WHERE id IN (
  SELECT DISTINCT property_id
  FROM bookings
  WHERE status IN ('reserved', 'occupied')
)
AND status = 'live';  -- only touch properties still showing as live

-- ── Step 4: Make sure any property with NO active booking is 'live' ────────
UPDATE properties
SET status = 'live'
WHERE status = 'reserved'
  AND id NOT IN (
    SELECT DISTINCT property_id FROM bookings
    WHERE status IN ('reserved', 'occupied')
  );
