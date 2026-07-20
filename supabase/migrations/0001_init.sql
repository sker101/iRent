create extension if not exists "uuid-ossp";

create type user_role as enum ('tenant', 'dalali', 'landlord', 'admin');
create type property_status as enum ('pending', 'live', 'reserved', 'occupied', 'rejected');
create type booking_status as enum ('reserved_pending', 'reserved', 'dalali_confirmed', 'occupied', 'cancelled');
create type payment_status as enum ('pending', 'success', 'failed');
create type room_type as enum ('single', 'double', 'self_contained', 'bedsitter', 'house', 'office', 'shop');

create table users (
  id uuid primary key default uuid_generate_v4(),
  auth_id uuid unique references auth.users(id) on delete cascade,
  full_name text not null,
  phone text unique,
  email text unique,
  role user_role not null default 'tenant',
  avatar_url text,
  verified boolean not null default false,
  id_document_url text,
  created_at timestamptz not null default now()
);

create table properties (
  id uuid primary key default uuid_generate_v4(),
  owner_id uuid not null references users(id),
  dalali_id uuid references users(id),
  title text not null,
  description text,
  price numeric not null,
  region text, district text, ward text, street text,
  latitude numeric, longitude numeric,
  room_type room_type not null,
  bedrooms int default 1,
  bathrooms int default 1,
  furnished boolean default false,
  gender_preference text default 'mixed',
  electricity text default 'independent',
  water text default 'independent',
  waste_fee numeric default 0,
  amenities text[] default '{}',
  status property_status not null default 'pending',
  available_from date,
  created_at timestamptz not null default now()
);

create table property_images (
  id uuid primary key default uuid_generate_v4(),
  property_id uuid not null references properties(id) on delete cascade,
  url text not null,
  sort_order int default 0
);

create table property_videos (
  id uuid primary key default uuid_generate_v4(),
  property_id uuid not null references properties(id) on delete cascade,
  url text not null
);

create table bookings (
  id uuid primary key default uuid_generate_v4(),
  property_id uuid not null references properties(id),
  tenant_id uuid not null references users(id),
  dalali_id uuid references users(id),
  landlord_id uuid not null references users(id),
  duration_months int not null default 1,
  rent_amount numeric not null,
  reservation_fee numeric not null,
  dalali_fee numeric not null,
  status booking_status not null default 'reserved_pending',
  payment_ref text,
  reserved_at timestamptz,
  dalali_confirmed_at timestamptz,
  occupied_at timestamptz,
  created_at timestamptz not null default now()
);

create table payment_transactions (
  id uuid primary key default uuid_generate_v4(),
  booking_id uuid not null references bookings(id),
  amount numeric not null,
  provider text not null,
  provider_ref text,
  status payment_status not null default 'pending',
  created_at timestamptz not null default now()
);

create table favorites (
  user_id uuid not null references users(id),
  property_id uuid not null references properties(id),
  created_at timestamptz not null default now(),
  primary key (user_id, property_id)
);

create table messages (
  id uuid primary key default uuid_generate_v4(),
  booking_id uuid not null references bookings(id),
  sender_id uuid not null references users(id),
  receiver_id uuid not null references users(id),
  body text not null,
  sent_at timestamptz not null default now(),
  read boolean default false
);

create table visits (
  id uuid primary key default uuid_generate_v4(),
  property_id uuid not null references properties(id),
  user_id uuid not null references users(id),
  scheduled_at timestamptz,
  status text default 'requested'
);

create table reports (
  id uuid primary key default uuid_generate_v4(),
  property_id uuid not null references properties(id),
  reporter_id uuid not null references users(id),
  reason text not null,
  status text default 'open',
  created_at timestamptz not null default now()
);

create table reviews (
  id uuid primary key default uuid_generate_v4(),
  property_id uuid not null references properties(id),
  user_id uuid not null references users(id),
  rating int check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

create table notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references users(id),
  title text not null,
  body text,
  read boolean default false,
  created_at timestamptz not null default now()
);

create table admin_actions (
  id uuid primary key default uuid_generate_v4(),
  admin_id uuid not null references users(id),
  action text not null,
  target_table text not null,
  target_id uuid not null,
  created_at timestamptz not null default now()
);

create index idx_properties_search on properties (district, ward, price, status);
create index idx_properties_status on properties (status);
create index idx_bookings_tenant on bookings (tenant_id);
create index idx_bookings_dalali on bookings (dalali_id);
create index idx_bookings_landlord on bookings (landlord_id);
create index idx_messages_booking on messages (booking_id);

alter table users enable row level security;
alter table properties enable row level security;
alter table bookings enable row level security;
alter table payment_transactions enable row level security;
alter table favorites enable row level security;
alter table messages enable row level security;
alter table reports enable row level security;
alter table admin_actions enable row level security;

create or replace function current_user_role() returns user_role as $$
  select role from users where auth_id = auth.uid();
$$ language sql stable;

create or replace function current_user_id() returns uuid as $$
  select id from users where auth_id = auth.uid();
$$ language sql stable;

create policy "own profile read" on users for select using (auth_id = auth.uid() or current_user_role() = 'admin');
create policy "own profile update" on users for update using (auth_id = auth.uid() or current_user_role() = 'admin');

create policy "read live properties" on properties for select using (status = 'live' or owner_id = current_user_id() or dalali_id = current_user_id() or current_user_role() = 'admin');
create policy "landlord/dalali manage own" on properties for insert with check (owner_id = current_user_id() or dalali_id = current_user_id());
create policy "landlord/dalali update own" on properties for update using (owner_id = current_user_id() or dalali_id = current_user_id() or current_user_role() = 'admin');

create policy "booking parties read" on bookings for select using (
  tenant_id = current_user_id() or dalali_id = current_user_id()
  or landlord_id = current_user_id() or current_user_role() = 'admin'
);
create policy "tenant creates booking" on bookings for insert with check (tenant_id = current_user_id());
create policy "parties update booking" on bookings for update using (
  tenant_id = current_user_id() or dalali_id = current_user_id()
  or landlord_id = current_user_id() or current_user_role() = 'admin'
);

create policy "tenant reads own payments" on payment_transactions for select using (
  exists (select 1 from bookings b where b.id = booking_id and b.tenant_id = current_user_id())
  or current_user_role() = 'admin'
);

create policy "own favorites" on favorites for all using (user_id = current_user_id());
create policy "own messages" on messages for select using (sender_id = current_user_id() or receiver_id = current_user_id());
create policy "send messages" on messages for insert with check (sender_id = current_user_id());
create policy "create report" on reports for insert with check (reporter_id = current_user_id());
create policy "admin reads reports" on reports for select using (current_user_role() = 'admin' or reporter_id = current_user_id());
