-- DEKK FOOD — schéma structuré et idempotent pour Supabase/PostgreSQL.
-- Les données de démonstration restent disponibles localement dans Flutter ;
-- ce schéma prépare la source de vérité de production sans exposer les
-- coordonnées clients au rôle anon.

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

create table if not exists public.restaurants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  -- Champ historique conservé pour les intégrations existantes.
  cuisine_type text not null default '',
  cuisine_types text[] not null default '{}',
  city text not null default 'Sénégal',
  zone text not null default 'Sénégal',
  neighborhood text not null default '',
  address text,
  map_query text,
  latitude double precision,
  longitude double precision,
  rating numeric(2,1) not null default 0 check (rating >= 0 and rating <= 5),
  review_count integer not null default 0 check (review_count >= 0),
  price_min_fcfa integer check (price_min_fcfa is null or price_min_fcfa >= 0),
  price_max_fcfa integer check (price_max_fcfa is null or price_max_fcfa >= 0),
  phone text,
  whatsapp text,
  image_url text,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now()),
  check (price_max_fcfa is null or price_min_fcfa is null or price_max_fcfa >= price_min_fcfa)
);

-- Migration non destructive depuis le premier schéma du projet.
alter table public.restaurants add column if not exists cuisine_type text;
alter table public.restaurants add column if not exists cuisine_types text[] not null default '{}';
alter table public.restaurants add column if not exists city text not null default 'Sénégal';
alter table public.restaurants add column if not exists zone text not null default 'Sénégal';
alter table public.restaurants add column if not exists map_query text;
alter table public.restaurants add column if not exists rating numeric(2,1) not null default 0;
alter table public.restaurants add column if not exists review_count integer not null default 0;
alter table public.restaurants add column if not exists price_min_fcfa integer;
alter table public.restaurants add column if not exists price_max_fcfa integer;
alter table public.restaurants add column if not exists image_url text;
alter table public.restaurants add column if not exists description text;
alter table public.restaurants add column if not exists updated_at timestamptz not null default timezone('utc'::text, now());
alter table public.restaurants alter column cuisine_type set default '';

-- Convertit l'ancienne valeur "Sénégalaise & Grillades" en liste typée.
update public.restaurants
set cuisine_types = regexp_split_to_array(cuisine_type, '[[:space:]]*(&|/|,)[[:space:]]*')
where coalesce(array_length(cuisine_types, 1), 0) = 0
  and coalesce(trim(cuisine_type), '') <> '';

create or replace function public.sync_restaurant_cuisine()
returns trigger
language plpgsql
as $$
begin
  if coalesce(array_length(new.cuisine_types, 1), 0) > 0 then
    new.cuisine_type := array_to_string(new.cuisine_types, ' & ');
  elsif coalesce(trim(new.cuisine_type), '') <> '' then
    new.cuisine_types := regexp_split_to_array(new.cuisine_type, '[[:space:]]*(&|/|,)[[:space:]]*');
  end if;
  return new;
end;
$$;

drop trigger if exists sync_restaurant_cuisine on public.restaurants;
create trigger sync_restaurant_cuisine
before insert or update of cuisine_type, cuisine_types on public.restaurants
for each row execute function public.sync_restaurant_cuisine();

create table if not exists public.menu_items (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  title text not null,
  description text,
  price numeric not null check (price >= 0),
  category text,
  image_url text,
  hygiene_note text,
  display_order integer not null default 0,
  is_available boolean not null default true,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

alter table public.menu_items add column if not exists image_url text;
alter table public.menu_items add column if not exists hygiene_note text;
alter table public.menu_items add column if not exists display_order integer not null default 0;
alter table public.menu_items add column if not exists created_at timestamptz not null default timezone('utc'::text, now());
alter table public.menu_items add column if not exists updated_at timestamptz not null default timezone('utc'::text, now());

-- Une commande est créée côté serveur (Edge Function / backend) avec le rôle
-- service : les coordonnées client ne sont jamais accessibles publiquement.
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  public_reference text not null unique,
  restaurant_id uuid not null references public.restaurants(id),
  status text not null default 'awaiting_confirmation'
    check (status in ('awaiting_confirmation', 'sent_to_restaurant', 'confirmed', 'completed', 'cancelled')),
  fulfillment_mode text not null
    check (fulfillment_mode in ('delivery', 'pickup')),
  customer_name text not null,
  customer_phone text not null,
  delivery_address text,
  note text,
  preferred_language text not null default 'Français',
  subtotal_fcfa integer not null check (subtotal_fcfa >= 0),
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  menu_item_id uuid references public.menu_items(id) on delete set null,
  item_name text not null,
  unit_price_fcfa integer not null check (unit_price_fcfa >= 0),
  quantity integer not null check (quantity > 0),
  created_at timestamptz not null default timezone('utc'::text, now())
);

-- Les favoris deviennent synchronisables dès qu'une authentification est
-- activée, tout en restant fonctionnels localement dans l'application.
create table if not exists public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  created_at timestamptz not null default timezone('utc'::text, now()),
  primary key (user_id, restaurant_id)
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists set_restaurant_updated_at on public.restaurants;
create trigger set_restaurant_updated_at
before update on public.restaurants
for each row execute function public.set_updated_at();

drop trigger if exists set_menu_item_updated_at on public.menu_items;
create trigger set_menu_item_updated_at
before update on public.menu_items
for each row execute function public.set_updated_at();

drop trigger if exists set_order_updated_at on public.orders;
create trigger set_order_updated_at
before update on public.orders
for each row execute function public.set_updated_at();

-- Index dédiés aux filtres zone/quartier et aux recherches tolérantes.
create index if not exists restaurants_zone_neighborhood_idx
  on public.restaurants (zone, neighborhood)
  where is_active = true;
create index if not exists restaurants_name_trgm_idx
  on public.restaurants using gin (name gin_trgm_ops);
create index if not exists restaurants_cuisine_trgm_idx
  on public.restaurants using gin (cuisine_type gin_trgm_ops);
create index if not exists menu_items_restaurant_available_idx
  on public.menu_items (restaurant_id, display_order)
  where is_available = true;
create index if not exists menu_items_title_trgm_idx
  on public.menu_items using gin (title gin_trgm_ops);
create index if not exists orders_restaurant_created_idx
  on public.orders (restaurant_id, created_at desc);
create index if not exists order_items_order_idx on public.order_items (order_id);

-- Lecture publique du guide uniquement. Les écritures de commande doivent
-- passer par une fonction serveur validée; elles restent donc sans policy anon.
alter table public.restaurants enable row level security;
alter table public.menu_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.favorites enable row level security;

drop policy if exists "public can read active restaurants" on public.restaurants;
create policy "public can read active restaurants"
on public.restaurants for select
using (is_active = true);

drop policy if exists "public can read available menu items" on public.menu_items;
create policy "public can read available menu items"
on public.menu_items for select
using (
  is_available = true
  and exists (
    select 1 from public.restaurants
    where restaurants.id = menu_items.restaurant_id
      and restaurants.is_active = true
  )
);

drop policy if exists "users can manage their favorites" on public.favorites;
create policy "users can manage their favorites"
on public.favorites for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

grant select on public.restaurants, public.menu_items to anon, authenticated;
grant select, insert, update, delete on public.favorites to authenticated;
