-- Fix infinite recursion in RLS policies.
-- The RLS policy for the `users` table calls `current_user_role()`, 
-- which in turn queries the `users` table, triggering the policy again.
-- Making these helper functions `security definer` ensures they bypass RLS,
-- breaking the loop.

create or replace function current_user_role() returns user_role as $$
  select role from users where auth_id = auth.uid();
$$ language sql stable security definer set search_path = public;

create or replace function current_user_id() returns uuid as $$
  select id from users where auth_id = auth.uid();
$$ language sql stable security definer set search_path = public;
