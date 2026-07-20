-- Phase 4: Add per-utility cost & note columns to properties
-- (amenities text[] already exists from 0001_init.sql)

alter table properties
  add column if not exists electricity_cost numeric default 0,
  add column if not exists electricity_note text default 'independent',
  add column if not exists water_cost      numeric default 0,
  add column if not exists water_note      text    default 'independent',
  add column if not exists waste_cost      numeric default 0,
  add column if not exists waste_note      text    default 'not charged',
  add column if not exists security_cost   numeric default 0,
  add column if not exists security_note   text    default 'not charged';

-- Allow anon to insert bookings in mock auth phase
do $$ begin
  if not exists (
    select 1 from pg_policies where policyname = 'mock anon insert bookings' and tablename = 'bookings'
  ) then
    execute 'create policy "mock anon insert bookings" on bookings for insert to anon with check (true)';
  end if;
end $$;

-- Allow anon to update property status to reserved
do $$ begin
  if not exists (
    select 1 from pg_policies where policyname = 'mock anon update property status' and tablename = 'properties'
  ) then
    execute 'create policy "mock anon update property status" on properties for update to anon using (true) with check (true)';
  end if;
end $$;

-- Allow anon to read bookings (so tenant can see their reservations)
do $$ begin
  if not exists (
    select 1 from pg_policies where policyname = 'mock anon read bookings' and tablename = 'bookings'
  ) then
    execute 'create policy "mock anon read bookings" on bookings for select to anon using (true)';
  end if;
end $$;
