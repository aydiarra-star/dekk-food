-- Table des restaurants
create table public.restaurants (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  cuisine_type text not null,
  neighborhood text not null,
  address text,
  phone text,
  whatsapp text,
  latitude double precision,
  longitude double precision,
  is_active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Table du menu
create table public.menu_items (
  id uuid default gen_random_uuid() primary key,
  restaurant_id uuid references public.restaurants(id) on delete cascade,
  title text not null,
  description text,
  price numeric not null,
  category text,
  is_available boolean default true
);
