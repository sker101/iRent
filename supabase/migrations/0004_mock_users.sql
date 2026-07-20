-- Insert dummy users into auth.users and public.users for mock identity flow

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token
) values (
  '00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'landlord@mock.com', '', now(), now(), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''
) on conflict (id) do nothing;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token
) values (
  '00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'dalali@mock.com', '', now(), now(), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''
) on conflict (id) do nothing;


insert into public.users (id, auth_id, full_name, email, role, verified)
values ('11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Mock Landlord', 'landlord@mock.com', 'landlord', true)
on conflict (id) do nothing;

insert into public.users (id, auth_id, full_name, email, role, verified)
values ('22222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'Mock Dalali', 'dalali@mock.com', 'dalali', true)
on conflict (id) do nothing;

