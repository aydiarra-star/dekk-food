-- =============================================================================
-- DEKK FOOD / DAKA FOOD — Migration 0001
-- Référentiel géographique national, types d'établissement et exploitation
-- -----------------------------------------------------------------------------
-- Principe : la table `restaurants` existante (supabase/schema.sql) est CONSERVÉE
-- et ÉTENDUE. Aucune donnée n'est supprimée. Les nouvelles tables la référencent.
-- Application : psql "$DATABASE_URL" -f supabase/migrations/0001_referentiel_et_catalogue.sql
-- =============================================================================

-- Les extensions sont FACULTATIVES : le schéma doit s'appliquer aussi sur une
-- instance PostgreSQL nue (sans modules contrib). Sous Supabase elles sont
-- présentes et débloquent les index trigrammes de recherche approchante.
-- gen_random_uuid() est natif depuis PostgreSQL 13 : pgcrypto n'est pas requis.
do $$
begin
  begin
    create extension if not exists pg_trgm;
  exception when others then
    raise notice 'pg_trgm indisponible : recherche approchante servie par les fonctions internes.';
  end;
  begin
    create extension if not exists unaccent;
  exception when others then
    raise notice 'unaccent indisponible : normalisation assurée par translate().';
  end;
end;
$$;

-- -----------------------------------------------------------------------------
-- 0. Utilitaires
-- -----------------------------------------------------------------------------
create or replace function public.maj_horodatage()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function public.maj_horodatage() is 'Met à jour updated_at à chaque modification.';

-- Distance approximative en mètres entre deux points GPS (formule de haversine).
create or replace function public.distance_metres(
  lat1 double precision, lon1 double precision,
  lat2 double precision, lon2 double precision
)
returns double precision
language sql
immutable
as $$
  select 6371000 * 2 * asin(
    sqrt(
      power(sin(radians(lat2 - lat1) / 2), 2) +
      cos(radians(lat1)) * cos(radians(lat2)) *
      power(sin(radians(lon2 - lon1) / 2), 2)
    )
  );
$$;

comment on function public.distance_metres is 'Distance à vol d''oiseau en mètres, utilisée pour le contrôle des doublons et du géocodage.';

-- Clé de comparaison d'un nom : minuscules, sans accents, sans ponctuation.
-- Implémenté avec translate() (fonction cœur) pour ne dépendre d'aucune extension.
create or replace function public.cle_nom(texte text)
returns text
language sql
immutable
as $$
  select nullif(
    regexp_replace(
      translate(
        lower(coalesce(texte, '')),
        'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ',
        'aaaaaaceeeeiiiinooooouuuuyyoa'
      ),
      '[^a-z0-9]+', '', 'g'
    ), ''
  );
$$;

comment on function public.cle_nom is 'Empreinte de comparaison des noms (minuscules, sans accents ni ponctuation).';

-- Mots trop génériques pour identifier un établissement : « Restaurant Le Lagon »
-- et « Restaurant La Douma » ne doivent pas être jugés proches.
create or replace function public.cle_nom_significative(texte text)
returns text
language sql
immutable
as $$
  with mots as (
    select mot
    from regexp_split_to_table(
      regexp_replace(
        translate(
          lower(coalesce(texte, '')),
          'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ',
          'aaaaaaceeeeiiiinooooouuuuyyoa'
        ),
        '[^a-z0-9]+', ' ', 'g'
      ),
      ' '
    ) as mot
    where mot <> ''
  ),
  -- Liste identique à MOTS_GENERIQUES de tools/catalogue/normalisation.py :
  -- les deux moteurs de déduplication doivent juger les mêmes paires.
  significatifs as (
    select distinct mot from mots
    where mot <> all (array[
      'restaurant', 'resto', 'restauration', 'hotel', 'complexe', 'chez', 'maison', 'snack',
      'bar', 'cafe', 'salon', 'table', 'cantine', 'grill', 'grillades', 'le', 'la', 'les',
      'l', 'd', 'de', 'du', 'des', 'au', 'aux', 'et', 'the', 'ex', 'residence', 'espace'
    ])
      and length(mot) > 2
  )
  select nullif(
    coalesce(
      (select string_agg(mot, ' ' order by mot) from significatifs),
      (select string_agg(distinct mot, ' ' order by mot) from mots)
    ),
    ''
  );
$$;

comment on function public.cle_nom_significative is 'Mots significatifs d''un nom (accents retirés, mots génériques écartés), dans l''ordre alphabétique.';

-- Similarité de deux NOMS, alignée sur la logique de tools/catalogue/dedoublonnage.py :
-- identité → 1 ; sinon meilleur score entre Dice des mots, Jaccard des mots et
-- ressemblance des identifiants significatifs ; contenance plafonnée à 0,82.
create or replace function public.similarite_noms(a text, b text)
returns numeric
language plpgsql
immutable
as $$
declare
  ca text := public.cle_nom(a);
  cb text := public.cle_nom(b);
  mots_a text[] := regexp_split_to_array(coalesce(public.cle_nom_significative(a), ''), ' ');
  mots_b text[] := regexp_split_to_array(coalesce(public.cle_nom_significative(b), ''), ' ');
  identifiant_a text;
  identifiant_b text;
  communs integer;
  score numeric := 0;
begin
  if ca is null or cb is null then
    return 0;
  end if;
  if ca = cb then
    return 1;
  end if;

  if array_length(mots_a, 1) is null or array_length(mots_b, 1) is null then
    return public.similarite_chaines(ca, cb);
  end if;

  select count(*) into communs
  from (
    select unnest(mots_a) intersect select unnest(mots_b)
  ) as mots_communs;

  score := greatest(
    2.0 * communs / (cardinality(mots_a) + cardinality(mots_b)),
    communs::numeric / greatest(cardinality(mots_a) + cardinality(mots_b) - communs, 1)
  );

  identifiant_a := array_to_string(mots_a, ' ');
  identifiant_b := array_to_string(mots_b, ' ');
  score := greatest(score, public.similarite_chaines(identifiant_a, identifiant_b));

  if length(identifiant_a) >= 4 and length(identifiant_b) >= 4
     and (position(identifiant_a in identifiant_b) > 0 or position(identifiant_b in identifiant_a) > 0) then
    score := greatest(score, 0.82);
  end if;

  return round(score, 4);
end;
$$;

comment on function public.similarite_noms is 'Similarité de deux noms d''établissements sur leurs mots significatifs (alignée sur le pipeline Python).';

-- Similarité de deux chaînes : coefficient de Dice sur les bigrammes.
-- Équivalent portable de similarity() de pg_trgm, sans dépendance d'extension.
create or replace function public.similarite_chaines(a text, b text)
returns numeric
language plpgsql
immutable
as $$
declare
  ca text := public.cle_nom(a);
  cb text := public.cle_nom(b);
  bigrammes_a integer;
  bigrammes_b integer;
  communs integer;
begin
  if ca is null or cb is null then
    return 0;
  end if;
  if ca = cb then
    return 1;
  end if;
  if length(ca) >= 4 and length(cb) >= 4
     and (position(ca in cb) > 0 or position(cb in ca) > 0) then
    return 0.82;  -- contenance : indice, jamais une preuve de doublon
  end if;

  select count(distinct substr(ca, i, 2)) into bigrammes_a
  from generate_series(1, greatest(length(ca) - 1, 1)) as i;

  select count(distinct substr(cb, i, 2)) into bigrammes_b
  from generate_series(1, greatest(length(cb) - 1, 1)) as i;

  select count(*) into communs
  from (
    select distinct substr(ca, i, 2) as bigramme
    from generate_series(1, greatest(length(ca) - 1, 1)) as i
    intersect
    select distinct substr(cb, i, 2)
    from generate_series(1, greatest(length(cb) - 1, 1)) as i
  ) as communs_bigrammes;

  if (bigrammes_a + bigrammes_b) = 0 then
    return 0;
  end if;

  return round(2.0 * communs / (bigrammes_a + bigrammes_b), 4);
end;
$$;

comment on function public.similarite_chaines is 'Similarité de deux chaînes (Dice sur bigrammes), utilisée pour suggérer des doublons.';

-- -----------------------------------------------------------------------------
-- 1. Référentiel géographique : région > département > commune > quartier
-- -----------------------------------------------------------------------------
create table if not exists public.regions (
  id            serial primary key,
  code          text not null unique,
  nom           text not null unique,
  chef_lieu     text,
  created_at    timestamptz not null default now()
);

create table if not exists public.departements (
  id            serial primary key,
  region_id     integer not null references public.regions(id) on delete restrict,
  code          text not null unique,
  nom           text not null,
  created_at    timestamptz not null default now(),
  unique (region_id, nom)
);

create table if not exists public.communes (
  id            serial primary key,
  departement_id integer not null references public.departements(id) on delete restrict,
  nom           text not null,
  type          text not null default 'commune'
                check (type in ('commune', 'ville', 'village', 'quartier_urbain')),
  code          text,
  latitude      double precision,
  longitude     double precision,
  created_at    timestamptz not null default now(),
  unique (departement_id, nom)
);

create table if not exists public.quartiers (
  id            serial primary key,
  commune_id    integer not null references public.communes(id) on delete cascade,
  nom           text not null,
  created_at    timestamptz not null default now(),
  unique (commune_id, nom)
);

create index if not exists idx_departements_region on public.departements(region_id);
create index if not exists idx_communes_departement on public.communes(departement_id);
create index if not exists idx_quartiers_commune on public.quartiers(commune_id);

-- -----------------------------------------------------------------------------
-- 2. Nomenclature : types d'établissement, catégories culinaires, services
-- -----------------------------------------------------------------------------
create table if not exists public.types_etablissement (
  id            serial primary key,
  code          text not null unique,
  libelle       text not null
);

create table if not exists public.categories_culinaires (
  id            serial primary key,
  code          text not null unique,
  libelle       text not null,
  parent_id     integer references public.categories_culinaires(id) on delete set null
);

create table if not exists public.services (
  id            serial primary key,
  code          text not null unique,
  libelle       text not null,
  categorie     text not null default 'reception'
                check (categorie in ('reception', 'commande', 'livraison', 'autre'))
);

create table if not exists public.allergenes (
  id            serial primary key,
  code          text not null unique,
  libelle       text not null
);

create table if not exists public.regimes_alimentaires (
  id            serial primary key,
  code          text not null unique,
  libelle       text not null
);

-- -----------------------------------------------------------------------------
-- 3. Sources, entreprises et gestionnaires
-- -----------------------------------------------------------------------------
create table if not exists public.sources (
  id                serial primary key,
  code              text not null unique,
  nom               text not null,
  url               text,
  type              text not null
                    check (type in ('annuaire', 'site_officiel', 'fiche_publique', 'reseau_social',
                                    'menu_officiel', 'guide', 'restaurateur', 'partenaire',
                                    'terrain', 'application_existante', 'recherche_web')),
  conditions_utilisation text,
  contenu_reutilisable   boolean not null default true,
  accessible        boolean not null default true,
  derniere_collecte_le timestamptz,
  notes             text,
  created_at        timestamptz not null default now()
);

create table if not exists public.entreprises (
  id                uuid primary key default gen_random_uuid(),
  raison_sociale    text not null,
  nom_commercial    text,
  forme_juridique   text,
  ninea             text,
  rccm              text,
  adresse           text,
  commune_id        integer references public.communes(id) on delete set null,
  telephone_pro     text,
  email_pro         text,
  site_web          text,
  source_id         integer references public.sources(id) on delete set null,
  source_url        text,
  date_verification date,
  statut_confirmation text not null default 'a_confirmer'
                    check (statut_confirmation in ('confirme', 'partiellement_confirme', 'inconnu', 'a_confirmer')),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  -- Aucune entreprise ne peut être publiée sans provenance vérifiable.
  constraint entreprises_source_obligatoire
    check (statut_confirmation = 'inconnu' or source_url is not null or source_id is not null)
);

create table if not exists public.gestionnaires (
  id                uuid primary key default gen_random_uuid(),
  entreprise_id     uuid references public.entreprises(id) on delete set null,
  nom_public        text not null,
  fonction          text,
  telephone_pro     text,
  email_pro         text,
  est_public        boolean not null default false,
  source_id         integer references public.sources(id) on delete set null,
  source_url        text,
  date_verification date,
  statut_confirmation text not null default 'a_confirmer'
                    check (statut_confirmation in ('confirme', 'partiellement_confirme', 'inconnu', 'a_confirmer')),
  created_at        timestamptz not null default now(),
  -- Règle de conformité : jamais de personne identifiée sans source publique documentée.
  constraint gestionnaires_source_obligatoire
    check (statut_confirmation = 'inconnu' or source_url is not null or source_id is not null)
);

comment on table public.gestionnaires is
  'Personnes ou dirigeants publiquement identifiés. Interdiction d''y stocker des données personnelles privées ; toute ligne doit porter une source.';

-- -----------------------------------------------------------------------------
-- 4. Extension de la table `restaurants` existante
-- -----------------------------------------------------------------------------
alter table public.restaurants
  add column if not exists numero_fiche        text,
  add column if not exists slug                text,
  add column if not exists nom_officiel        text,
  add column if not exists nom_commercial      text,
  add column if not exists type_etablissement_id integer references public.types_etablissement(id) on delete set null,
  add column if not exists description_courte  text,
  add column if not exists description_longue  text,
  add column if not exists statut              text not null default 'a_verifier',
  add column if not exists niveau_verification text not null default 'a_confirmer',
  add column if not exists region_id           integer references public.regions(id) on delete set null,
  add column if not exists departement_id      integer references public.departements(id) on delete set null,
  add column if not exists commune_id          integer references public.communes(id) on delete set null,
  add column if not exists quartier_id         integer references public.quartiers(id) on delete set null,
  add column if not exists ville_libre         text,
  add column if not exists adresse_complete    text,
  add column if not exists points_de_repere    text,
  add column if not exists gps_verifie         boolean not null default false,
  add column if not exists gps_source_id       integer references public.sources(id) on delete set null,
  add column if not exists fourchette_prix_min integer,
  add column if not exists fourchette_prix_max integer,
  add column if not exists devise              text not null default 'XOF',
  add column if not exists ambiance            text,
  add column if not exists clientele           text,
  add column if not exists modes_paiement      text[],
  add column if not exists accessibilite       text,
  add column if not exists equipements         text[],
  add column if not exists entreprise_id       uuid references public.entreprises(id) on delete set null,
  add column if not exists site_web            text,
  add column if not exists facebook            text,
  add column if not exists instagram           text,
  add column if not exists commande_en_ligne_url text,
  add column if not exists reservation_url     text,
  add column if not exists image_principale_url text,
  add column if not exists source_principale_id integer references public.sources(id) on delete set null,
  add column if not exists source_principale_url text,
  add column if not exists date_collecte       date,
  add column if not exists derniere_verification_le date,
  add column if not exists commentaire_verification text,
  add column if not exists est_publication_visible boolean not null default false,
  add column if not exists origine_donnee      text,
  add column if not exists updated_at          timestamptz not null default now(),
  add column if not exists cree_par            uuid,
  add column if not exists maj_par             uuid;

-- Contraintes de domaine (ajoutées séparément : ADD CONSTRAINT n'est pas idempotent
-- en PostgreSQL, elles sont donc enveloppées dans un bloc conditionnel).
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'restaurants_statut_check') then
    alter table public.restaurants add constraint restaurants_statut_check
      check (statut in ('ouvert', 'ferme_temporairement', 'ferme_definitivement', 'a_verifier'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'restaurants_niveau_verification_check') then
    alter table public.restaurants add constraint restaurants_niveau_verification_check
      check (niveau_verification in ('verifie', 'partiellement_verifie', 'a_confirmer',
                                     'information_indisponible', 'fermeture_a_verifier'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'restaurants_coordonnees_check') then
    alter table public.restaurants add constraint restaurants_coordonnees_check
      check (
        (latitude is null and longitude is null)
        or (latitude between -90 and 90 and longitude between -180 and 180)
      );
  end if;

  if not exists (select 1 from pg_constraint where conname = 'restaurants_fourchette_prix_check') then
    alter table public.restaurants add constraint restaurants_fourchette_prix_check
      check (fourchette_prix_min is null or fourchette_prix_max is null
             or fourchette_prix_min <= fourchette_prix_max);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'restaurants_numero_fiche_key') then
    alter table public.restaurants add constraint restaurants_numero_fiche_key unique (numero_fiche);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'restaurants_slug_key') then
    alter table public.restaurants add constraint restaurants_slug_key unique (slug);
  end if;

  -- Un établissement publié doit au minimum être localisé au niveau région.
  if not exists (select 1 from pg_constraint where conname = 'restaurants_publication_localisation_check') then
    alter table public.restaurants add constraint restaurants_publication_localisation_check
      check (est_publication_visible = false or region_id is not null);
  end if;
end;
$$;

-- Évolution assumée : une fiche peut être INCOMPLÈTE et le signaler plutôt que
-- d'obliger à inventer une valeur. Les anciennes colonnes obligatoires de la
-- version 2.1.0 deviennent facultatives ; la complétude est mesurée par les vues
-- d'administration (v_file_travail, v_qualite_catalogue).
alter table public.restaurants alter column cuisine_type drop not null;
alter table public.restaurants alter column neighborhood drop not null;

create index if not exists idx_restaurants_region on public.restaurants(region_id);
create index if not exists idx_restaurants_departement on public.restaurants(departement_id);
create index if not exists idx_restaurants_commune on public.restaurants(commune_id);
create index if not exists idx_restaurants_quartier on public.restaurants(quartier_id);
create index if not exists idx_restaurants_statut on public.restaurants(statut);
create index if not exists idx_restaurants_niveau on public.restaurants(niveau_verification);
create index if not exists idx_restaurants_visible on public.restaurants(est_publication_visible) where est_publication_visible;
-- Index trigrammes (recherche approchante) : uniquement si pg_trgm est disponible.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_trgm') then
    create index if not exists idx_restaurants_nom_trgm on public.restaurants using gin (name gin_trgm_ops);
    create index if not exists idx_restaurants_cuisine_trgm on public.restaurants using gin (cuisine_type gin_trgm_ops);
    create index if not exists idx_restaurants_quartier_trgm on public.restaurants using gin (neighborhood gin_trgm_ops);
    create index if not exists idx_communes_nom_trgm on public.communes using gin (nom gin_trgm_ops);
    create index if not exists idx_quartiers_nom_trgm on public.quartiers using gin (nom gin_trgm_ops);
    create index if not exists idx_plats_nom_trgm on public.plats using gin (nom gin_trgm_ops);
  else
    raise notice 'Index trigrammes non créés (pg_trgm absent) : la similarité est calculée par similarite_chaines().';
  end if;
end;
$$;
create index if not exists idx_restaurants_telephone on public.restaurants(phone);
create index if not exists idx_restaurants_site on public.restaurants(site_web);
-- Recherche plein texte simple (nom + description + quartier), sans table auxiliaire.
create index if not exists idx_restaurants_fts on public.restaurants using gin (
  to_tsvector('french',
    coalesce(name, '') || ' ' || coalesce(description_courte, '') || ' ' ||
    coalesce(cuisine_type, '') || ' ' || coalesce(neighborhood, ''))
);

drop trigger if exists trg_restaurants_updated_at on public.restaurants;
create trigger trg_restaurants_updated_at
  before update on public.restaurants
  for each row execute function public.maj_horodatage();

drop trigger if exists trg_entreprises_updated_at on public.entreprises;
create trigger trg_entreprises_updated_at
  before update on public.entreprises
  for each row execute function public.maj_horodatage();

-- -----------------------------------------------------------------------------
-- 5. Relations : catégories, exploitation, contacts, provenance
-- -----------------------------------------------------------------------------
create table if not exists public.etablissement_categories (
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  categorie_id  integer not null references public.categories_culinaires(id) on delete cascade,
  est_principale boolean not null default false,
  primary key (restaurant_id, categorie_id)
);

create table if not exists public.etablissement_exploitation (
  id                uuid primary key default gen_random_uuid(),
  restaurant_id     uuid not null references public.restaurants(id) on delete cascade,
  entreprise_id     uuid references public.entreprises(id) on delete set null,
  gestionnaire_id   uuid references public.gestionnaires(id) on delete set null,
  role              text not null
                    check (role in ('proprietaire', 'exploitant', 'gerant', 'franchise', 'groupe')),
  source_id         integer references public.sources(id) on delete set null,
  source_url        text,
  date_verification date,
  statut_confirmation text not null default 'a_confirmer'
                    check (statut_confirmation in ('confirme', 'partiellement_confirme', 'inconnu', 'a_confirmer')),
  unique (restaurant_id, entreprise_id, gestionnaire_id, role),
  constraint exploitation_cible_check
    check (entreprise_id is not null or gestionnaire_id is not null),
  constraint exploitation_source_obligatoire
    check (statut_confirmation = 'inconnu' or source_url is not null or source_id is not null)
);

comment on table public.etablissement_exploitation is
  'Qui possède / exploite quoi. Le nom affiché reste « Propriétaire non renseigné » tant qu''aucune source publique fiable n''est enregistrée (statut inconnu).';

create table if not exists public.contacts (
  id                uuid primary key default gen_random_uuid(),
  restaurant_id     uuid not null references public.restaurants(id) on delete cascade,
  type              text not null
                    check (type in ('telephone', 'whatsapp', 'email', 'site_web', 'facebook',
                                    'instagram', 'tiktok', 'x', 'commande_en_ligne', 'reservation', 'autre')),
  valeur            text not null,
  libelle           text,
  est_professionnel boolean not null default true,
  est_principal     boolean not null default false,
  confirme          boolean not null default false,
  source_id         integer references public.sources(id) on delete set null,
  source_url        text,
  date_collecte     date,
  date_verification date,
  created_at        timestamptz not null default now(),
  unique (restaurant_id, type, valeur)
);

create index if not exists idx_contacts_restaurant on public.contacts(restaurant_id);
create index if not exists idx_contacts_valeur on public.contacts(valeur);
create index if not exists idx_contacts_type on public.contacts(type);

comment on table public.contacts is
  'Coordonnées PROFESSIONNELLES uniquement (aucun numéro personnel privé). Chaque valeur porte sa source et sa date de collecte.';

create table if not exists public.etablissement_sources (
  id                uuid primary key default gen_random_uuid(),
  restaurant_id     uuid not null references public.restaurants(id) on delete cascade,
  source_id         integer not null references public.sources(id) on delete restrict,
  url_exacte        text,
  date_collecte     date not null default current_date,
  donnees_collectees text,
  niveau_confiance  text not null default 'moyen'
                    check (niveau_confiance in ('eleve', 'moyen', 'faible')),
  collecte_par      text,
  created_at        timestamptz not null default now()
);

create index if not exists idx_etablissement_sources_restaurant on public.etablissement_sources(restaurant_id);
create unique index if not exists idx_etablissement_sources_unique
  on public.etablissement_sources(restaurant_id, source_id, coalesce(url_exacte, ''));

create table if not exists public.verifications (
  id                uuid primary key default gen_random_uuid(),
  restaurant_id     uuid not null references public.restaurants(id) on delete cascade,
  date_verification date not null default current_date,
  verificateur      text,
  methode           text not null
                    check (methode in ('appel', 'whatsapp', 'email', 'site_officiel', 'visite',
                                       'annuaire', 'restaurateur', 'partenaire', 'import')),
  champs_verifies   text[],
  resultat          text not null default 'partiellement_confirme'
                    check (resultat in ('confirme', 'partiellement_confirme', 'infirme', 'injoignable')),
  commentaire       text,
  created_at        timestamptz not null default now()
);

create index if not exists idx_verifications_restaurant on public.verifications(restaurant_id, date_verification desc);
