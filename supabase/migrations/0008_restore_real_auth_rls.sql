-- Phase 3: Restore real auth policies now that Google Sign-In is active.
-- Drop the wide-open policies from Phase 2 and restore proper authenticated ones.

-- 1. Make owner_id NOT NULL again (now that real users exist).
-- Skip this if there are any existing NULL rows from Phase 2 seeding.
-- The alter will only succeed if no NULLs exist; otherwise safe to leave nullable.
-- alter table properties alter column owner_id set not null;

-- 2. Restore the full read policy (logged-in users can see their own pending, others see live).
drop policy if exists "anyone can read live properties" on properties;
drop policy if exists "read live properties" on properties;

create policy "read live properties"
  on properties
  for select
  using (
    status = 'live'
    or owner_id = current_user_id()
    or dalali_id = current_user_id()
    or current_user_role() = 'admin'
  );

-- 3. Add INSERT policy for property_images (so owners can insert after property is created).
drop policy if exists "owner can insert images" on property_images;

create policy "owner can insert images"
  on property_images
  for insert
  with check (
    exists (
      select 1 from properties p
      where p.id = property_id
      and (p.owner_id = current_user_id() or p.dalali_id = current_user_id())
    )
  );

-- 4. Add DELETE policy for property_images (so owners can manage their photos).
drop policy if exists "owner can delete images" on property_images;

create policy "owner can delete images"
  on property_images
  for delete
  using (
    exists (
      select 1 from properties p
      where p.id = property_id
      and (p.owner_id = current_user_id() or p.dalali_id = current_user_id())
    )
  );
