-- Phase 3: Setup Storage Bucket for Property Images

insert into storage.buckets (id, name, public)
values ('properties', 'properties', true)
on conflict (id) do nothing;

-- Allow public read access to properties bucket
create policy "anyone can read properties bucket" on storage.objects
  for select using (bucket_id = 'properties');

-- Allow anonymous uploads for our mock phase
-- (In production, this would check auth.uid() and possibly the properties table)
create policy "anon can upload properties bucket" on storage.objects
  for insert to anon with check (bucket_id = 'properties');
  
create policy "authenticated can upload properties bucket" on storage.objects
  for insert to authenticated with check (bucket_id = 'properties');
