-- 0011_fix_rls_users_booking.sql
-- Allow tenants to read the full_name and role of landlords/dalalis 
-- involved in their bookings. This fixes "Unknown" landlord name in My Room.

CREATE POLICY "read booking counterparties"
ON users FOR SELECT
USING (
  -- You can always read your own profile
  auth_id = auth.uid()
  OR
  -- Tenants can read landlord/dalali names for their own bookings
  id IN (
    SELECT landlord_id FROM bookings 
    WHERE tenant_id = (SELECT id FROM users WHERE auth_id = auth.uid())
    UNION
    SELECT dalali_id FROM bookings 
    WHERE tenant_id = (SELECT id FROM users WHERE auth_id = auth.uid())
      AND dalali_id IS NOT NULL
  )
  OR
  -- Landlords/dalalis can read their tenants
  id IN (
    SELECT tenant_id FROM bookings 
    WHERE landlord_id = (SELECT id FROM users WHERE auth_id = auth.uid())
       OR dalali_id   = (SELECT id FROM users WHERE auth_id = auth.uid())
  )
);

-- Also clean up duplicate bookings on the DB side: keep only the LATEST booking
-- per tenant+property combo so we don't show duplicates in My Room.
DELETE FROM bookings
WHERE id NOT IN (
  SELECT DISTINCT ON (tenant_id, property_id) id
  FROM bookings
  ORDER BY tenant_id, property_id, reserved_at DESC NULLS LAST
);

-- Add a unique constraint so it can never happen again:
-- (One booking per tenant per property)
ALTER TABLE bookings 
  DROP CONSTRAINT IF EXISTS bookings_tenant_property_unique;

ALTER TABLE bookings 
  ADD CONSTRAINT bookings_tenant_property_unique 
  UNIQUE (tenant_id, property_id);
