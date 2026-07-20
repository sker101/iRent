-- Phase 2: make properties publicly readable without real user auth.
-- The full schema (owner_id, dalali_id, write policies) lives in 0001_init.sql
-- and will be re-activated once real auth returns.

-- 1. Make owner_id nullable so we can seed data without user accounts.
alter table properties alter column owner_id drop not null;

-- 2. Replace the authenticated-only select policy with a public one.
drop policy if exists "read live properties" on properties;

create policy "anyone can read live properties" on properties
  for select using (status = 'live');

-- 3. Property images: allow public reads (no policy existed before).
drop policy if exists "anyone can read property images" on property_images;

create policy "anyone can read property images" on property_images
  for select using (true);
