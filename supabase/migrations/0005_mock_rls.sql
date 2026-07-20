-- Temporary RLS policies for local mock development
-- Allows unauthenticated users to insert properties

create policy "mock anon insert properties" on properties for insert to anon with check (true);
create policy "mock anon update properties" on properties for update to anon using (true);

-- Same for property_images if we need them later
create policy "mock anon insert images" on property_images for insert to anon with check (true);
