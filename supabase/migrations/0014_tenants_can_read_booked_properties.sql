-- 0014_tenants_can_read_booked_properties.sql
--
-- PROBLEM: The properties table has a policy: `status = 'live'` only.
-- When a property is marked 'reserved' after payment, the Supabase join
-- from bookings → properties returns NULL for the tenant, causing My Room
-- to show "Property" / "Unknown" with no image and no click.
--
-- FIX: Add a second SELECT policy so that a tenant can always read a property
-- they have an active booking for, regardless of the property's status.

-- Allow tenants to read properties they have booked (any status)
CREATE POLICY "tenants can read their booked properties"
ON properties FOR SELECT
USING (
  id IN (
    SELECT property_id
    FROM bookings
    WHERE tenant_id = (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
    AND status IN ('reserved', 'occupied')
  )
);

-- Also allow landlords/dalalis to always read their own properties (any status)
CREATE POLICY "owners can read their own properties"
ON properties FOR SELECT
USING (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR
  dalali_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
