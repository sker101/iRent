-- Allow authenticated users to insert their own row in the users table.
-- This is required immediately after a magic-link sign-in, before any
-- users row exists (so current_user_id() would return null and fail).
-- We therefore use auth.uid() directly instead of the helper function.

create policy "insert own profile"
  on users
  for insert
  with check (auth_id = auth.uid());
