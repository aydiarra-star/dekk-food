-- =============================================================================
-- DEKK FOOD / DAKA FOOD — Migration 0002
-- Menus, plats, prix, promotions, images et droits, horaires, services, livraison
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Menus et plats
-- -----------------------------------------------------------------------------
create table if not exists public.menus (
  id                uuid primary key default gen_random_uuid(),
  restaurant_id     uuid not null references public.restaurants(id) on delete cascade,
  nom               text not null,
  type              text not null default 'carte'
                    check (type in ('carte', 'menu_midi', 'plat_du_jour', 'menu_fete',
                                    'menu_enfant', 'boissons', 'promotion', 'formule', 'traiteur')),
  devise            text not null default 'XOF',
  statut            text not null default 'a_confirmer'
                    check (statut in ('confirme', 'incomplet', 'a_confirmer', 'obsolete')),
  est_actif         boolean not null default true,
  date_debut        date,
  date_fin          date,
  source_id         integer references public.sources(id) on delete set null,
  source_url        text,
  date_collecte     date,
  derniere_maj      date,
  commentaire       text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint menus_periode_check check (date_debut is null or date_fin is null or date_debut <= date_fin),
  -- Un menu publié doit indiquer d'où il vient : aucun menu inventé.
  constraint menus_source_obligatoire check (statut = 'a_confirmer' or source_url is not null or source_id is not null),
  -- Un même établissement n'a qu'un menu d'un type donné portant ce nom (idempotence des imports).
  unique (restaurant_id, nom, type)
);

create table if not exists public.menu_sections (
  id                uuid primary key default gen_random_uuid(),
  menu_id           uuid not null references public.menus(id) on delete cascade,
  nom               text not null,
  ordre             integer not null default 0,
  unique (menu_id, nom)
);

create table if not exists public.plats (
  id                uuid primary key default gen_random_uuid(),
  restaurant_id     uuid not null references public.restaurants(id) on delete cascade,
  menu_id           uuid references public.menus(id) on delete set null,
  section_id        uuid references public.menu_sections(id) on delete set null,
  nom               text not null,
  description       text,
  categorie         text not null default 'plat_principal'
                    check (categorie in ('entree', 'plat_principal', 'accompagnement', 'dessert',
                                         'boisson', 'formule', 'menu_enfant', 'specialite', 'petit_dejeuner')),
  prix              numeric(12,2),
  devise            text not null default 'XOF',
  taille_portion    text,
  options           text,
  variantes         text,
  disponibilite     text not null default 'a_confirmer'
                    check (disponibilite in ('permanent', 'saisonnier', 'menu_du_jour', 'a_confirmer', 'indisponible')),
  date_debut        date,
  date_fin          date,
  statut_confirmation text not null default 'a_confirmer'
                    check (statut_confirmation in ('confirme', 'partiellement_confirme', 'a_confirmer', 'inconnu')),
  source_id         integer references public.sources(id) on delete set null,
  source_url        text,
  date_collecte     date,
  derniere_maj      date,
  est_actif         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint plats_prix_check check (prix is null or prix >= 0),
  -- Un prix ne peut être publié comme confirmé sans provenance.
  constraint plats_prix_source_check
    check (prix is null or statut_confirmation <> 'confirme' or source_url is not null or source_id is not null),
  constraint plats_disponibilite_periode_check
    check (date_debut is null or date_fin is null or date_debut <= date_fin),
  unique (menu_id, nom)
);

create index if not exists idx_menus_restaurant on public.menus(restaurant_id, type);
create index if not exists idx_menus_actifs on public.menus(restaurant_id) where est_actif;
create index if not exists idx_plats_restaurant on public.plats(restaurant_id);
create index if not exists idx_plats_menu on public.plats(menu_id);
create index if not exists idx_plats_categorie on public.plats(categorie);

-- Index trigrammes : uniquement lorsque pg_trgm est disponible (cf. migration 0001).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_trgm') then
    create index if not exists idx_plats_nom_trgm on public.plats using gin (nom gin_trgm_ops);
  end if;
end;
$$;

drop trigger if exists trg_menus_updated_at on public.menus;
create trigger trg_menus_updated_at before update on public.menus
  for each row execute function public.maj_horodatage();

drop trigger if exists trg_plats_updated_at on public.plats;
create trigger trg_plats_updated_at before update on public.plats
  for each row execute function public.maj_horodatage();

create table if not exists public.plat_allergenes (
  plat_id       uuid not null references public.plats(id) on delete cascade,
  allergene_id  integer not null references public.allergenes(id) on delete cascade,
  source_url    text,
  primary key (plat_id, allergene_id)
);

create table if not exists public.plat_regimes (
  plat_id       uuid not null references public.plats(id) on delete cascade,
  regime_id     integer not null references public.regimes_alimentaires(id) on delete cascade,
  source_url    text,
  primary key (plat_id, regime_id)
);

create table if not exists public.plat_promotions (
  id            uuid primary key default gen_random_uuid(),
  plat_id       uuid not null references public.plats(id) on delete cascade,
  libelle       text not null,
  prix_promo    numeric(12,2),
  date_debut    date not null,
  date_fin      date,
  source_url    text,
  created_at    timestamptz not null default now(),
  constraint promotions_periode_check check (date_fin is null or date_debut <= date_fin),
  constraint promotions_source_obligatoire check (source_url is not null)
);

comment on table public.plat_promotions is
  'Promotions datées. La contrainte promotions_source_obligatoire interdit toute promotion sans provenance : aucune promotion inventée.';

-- -----------------------------------------------------------------------------
-- 2. Images et droits
-- -----------------------------------------------------------------------------
create table if not exists public.images (
  id                uuid primary key default gen_random_uuid(),
  restaurant_id     uuid references public.restaurants(id) on delete cascade,
  plat_id           uuid references public.plats(id) on delete cascade,
  url               text not null,
  type_media        text not null default 'photo_autre'
                    check (type_media in ('photo_facade', 'photo_salle', 'photo_terrasse', 'photo_plat',
                                          'photo_cadre', 'logo', 'illustration_generique', 'photo_autre')),
  legende           text,
  est_principale    boolean not null default false,
  est_illustration_generique boolean not null default false,
  correspondance_verifiee boolean not null default false,
  auteur            text,
  licence           text,
  autorisation_usage text,
  source_id         integer references public.sources(id) on delete set null,
  source_url        text,
  date_collecte     date,
  ordre             integer not null default 0,
  created_at        timestamptz not null default now(),
  constraint images_cible_check check (restaurant_id is not null or plat_id is not null),
  -- Une image générique ne peut jamais être présentée comme correspondant à l'établissement.
  constraint images_generique_coherence
    check (not est_illustration_generique or correspondance_verifiee = false),
  -- Toute image de plat doit porter une licence ou une autorisation explicite.
  constraint images_plat_droits_check
    check (type_media <> 'photo_plat' or licence is not null or autorisation_usage is not null
           or est_illustration_generique)
);

create index if not exists idx_images_restaurant on public.images(restaurant_id, ordre);
create index if not exists idx_images_plat on public.images(plat_id);
-- Idempotence des imports : une même URL n'est enregistrée qu'une fois par cible.
create unique index if not exists idx_images_url_unique
  on public.images(coalesce(restaurant_id, '00000000-0000-0000-0000-000000000000'::uuid), url);

create unique index if not exists idx_promotions_unique
  on public.plat_promotions(plat_id, libelle, date_debut);
-- Une seule image principale par établissement.
create unique index if not exists idx_images_principale_unique
  on public.images(restaurant_id) where est_principale and restaurant_id is not null;

comment on table public.images is
  'Chaque image est liée à SON établissement ou à SON plat. Les images de banque sont marquées est_illustration_generique = true et ne peuvent pas être présentées comme authentiques.';

-- -----------------------------------------------------------------------------
-- 3. Contacts structurés : horaires, services, livraison, équipements
-- -----------------------------------------------------------------------------
create table if not exists public.horaires (
  id                uuid primary key default gen_random_uuid(),
  restaurant_id     uuid not null references public.restaurants(id) on delete cascade,
  jour              smallint not null check (jour between 0 and 6), -- 0 = dimanche
  service           text not null default 'continu'
                    check (service in ('continu', 'midi', 'soir')),
  ferme             boolean not null default false,
  ouverture         time,
  fermeture         time,
  confirme          boolean not null default false,
  source_id         integer references public.sources(id) on delete set null,
  source_url        text,
  date_verification date,
  unique (restaurant_id, jour, service),
  constraint horaires_coherence check (ferme or (ouverture is not null and fermeture is not null))
);

create table if not exists public.horaires_exceptionnels (
  id                uuid primary key default gen_random_uuid(),
  restaurant_id     uuid not null references public.restaurants(id) on delete cascade,
  libelle           text not null,
  date_debut        date not null,
  date_fin          date,
  ferme             boolean not null default true,
  ouverture         time,
  fermeture         time,
  source_id         integer references public.sources(id) on delete set null,
  source_url        text,
  constraint horaires_exceptionnels_periode check (date_fin is null or date_debut <= date_fin)
);

create index if not exists idx_horaires_restaurant on public.horaires(restaurant_id);

create table if not exists public.etablissement_services (
  restaurant_id     uuid not null references public.restaurants(id) on delete cascade,
  service_id        integer not null references public.services(id) on delete cascade,
  details           text,
  confirme          boolean not null default false,
  source_id         integer references public.sources(id) on delete set null,
  source_url        text,
  date_verification date,
  primary key (restaurant_id, service_id)
);

create table if not exists public.zones_livraison (
  id                uuid primary key default gen_random_uuid(),
  restaurant_id     uuid not null references public.restaurants(id) on delete cascade,
  commune_id        integer references public.communes(id) on delete set null,
  libelle_zone      text,
  frais_livraison   numeric(12,2),
  devise            text not null default 'XOF',
  delai_estime      text,
  minimum_commande  numeric(12,2),
  confirme          boolean not null default false,
  source_id         integer references public.sources(id) on delete set null,
  source_url        text,
  constraint zones_livraison_cible_check check (commune_id is not null or libelle_zone is not null),
  -- Aucun tarif ni délai de livraison ne peut être affiché comme confirmé sans source.
  constraint zones_livraison_source_check
    check (not confirme or source_url is not null or source_id is not null)
);

comment on table public.zones_livraison is
  'Frais et délais ne sont affichés comme confirmés que si une source les documente (zones_livraison_source_check).';

create index if not exists idx_zones_livraison_restaurant on public.zones_livraison(restaurant_id);
create unique index if not exists idx_zones_livraison_unique
  on public.zones_livraison(restaurant_id, coalesce(commune_id, 0), coalesce(libelle_zone, ''));

-- -----------------------------------------------------------------------------
-- 4. Avis, signalements, corrections, revendications
-- -----------------------------------------------------------------------------
create table if not exists public.avis (
  id                uuid primary key default gen_random_uuid(),
  restaurant_id     uuid not null references public.restaurants(id) on delete cascade,
  auteur_nom        text,
  auteur_id         uuid,
  note              smallint check (note between 1 and 5),
  commentaire       text,
  statut            text not null default 'en_attente'
                    check (statut in ('en_attente', 'publie', 'rejete')),
  motif_rejet       text,
  modere_par        uuid,
  modere_le         timestamptz,
  created_at        timestamptz not null default now()
);

create index if not exists idx_avis_restaurant on public.avis(restaurant_id, statut);

create table if not exists public.signalements (
  id                uuid primary key default gen_random_uuid(),
  restaurant_id     uuid references public.restaurants(id) on delete cascade,
  type              text not null default 'erreur'
                    check (type in ('erreur', 'fermeture', 'doublon', 'donnee_personnelle',
                                    'droit_image', 'retrait', 'autre')),
  message           text not null,
  contact_email     text,
  statut            text not null default 'nouveau'
                    check (statut in ('nouveau', 'en_cours', 'traite', 'rejete')),
  traite_par        uuid,
  traite_le         timestamptz,
  created_at        timestamptz not null default now()
);

create index if not exists idx_signalements_statut on public.signalements(statut, created_at desc);

create table if not exists public.demandes_correction (
  id                uuid primary key default gen_random_uuid(),
  restaurant_id     uuid not null references public.restaurants(id) on delete cascade,
  champs            jsonb not null,
  message           text,
  contact_email     text,
  statut            text not null default 'nouvelle'
                    check (statut in ('nouvelle', 'en_cours', 'appliquee', 'rejetee')),
  traite_par        uuid,
  traite_le         timestamptz,
  created_at        timestamptz not null default now()
);

create table if not exists public.revendications (
  id                uuid primary key default gen_random_uuid(),
  restaurant_id     uuid not null references public.restaurants(id) on delete cascade,
  demandeur_nom     text not null,
  fonction          text,
  email_pro         text not null,
  telephone_pro     text,
  preuve_type       text check (preuve_type in ('email_domaine', 'document_officiel', 'appel', 'site_web', 'autre')),
  preuve_reference  text,
  statut            text not null default 'en_attente'
                    check (statut in ('en_attente', 'en_verification', 'verifiee', 'rejetee')),
  verifie_par       uuid,
  verifie_le        timestamptz,
  commentaire       text,
  created_at        timestamptz not null default now()
);

comment on table public.revendications is
  'Revendication de fiche par un restaurateur. Le statut « verifiee » exige une vérification HUMAINE : une revendication n''attribue jamais automatiquement le badge « vérifié » à la fiche.';

-- -----------------------------------------------------------------------------
-- 5. Import de masse, journal, doublons
-- -----------------------------------------------------------------------------
create table if not exists public.import_lots (
  id                uuid primary key default gen_random_uuid(),
  nom_fichier       text,
  format            text check (format in ('csv', 'xlsx', 'json', 'integration', 'manuel')),
  source_id         integer references public.sources(id) on delete set null,
  entre_par         text,
  statut            text not null default 'en_cours'
                    check (statut in ('en_cours', 'termine', 'echec', 'annule')),
  total_lignes      integer not null default 0,
  ajoutees          integer not null default 0,
  mises_a_jour      integer not null default 0,
  rejetees          integer not null default 0,
  doublons          integer not null default 0,
  a_verifier        integer not null default 0,
  rapport           jsonb,
  messages          text[],
  created_at        timestamptz not null default now(),
  termine_le        timestamptz
);

create table if not exists public.import_lignes (
  id                uuid primary key default gen_random_uuid(),
  lot_id            uuid not null references public.import_lots(id) on delete cascade,
  numero_ligne      integer not null,
  donnees           jsonb not null,
  empreinte         text,
  statut            text not null default 'en_attente'
                    check (statut in ('en_attente', 'ajoutee', 'mise_a_jour', 'rejetee', 'doublon', 'a_verifier')),
  messages          text[],
  restaurant_id     uuid references public.restaurants(id) on delete set null,
  created_at        timestamptz not null default now()
);

create index if not exists idx_import_lignes_lot on public.import_lignes(lot_id, statut);

create table if not exists public.doublons_suspects (
  id                uuid primary key default gen_random_uuid(),
  restaurant_a      uuid not null references public.restaurants(id) on delete cascade,
  restaurant_b      uuid not null references public.restaurants(id) on delete cascade,
  score             numeric(5,2) not null,
  motifs            text[] not null default '{}',
  statut            text not null default 'a_examiner'
                    check (statut in ('a_examiner', 'distincts', 'fusionnes')),
  examine_par       uuid,
  examine_le        timestamptz,
  commentaire       text,
  created_at        timestamptz not null default now(),
  constraint doublons_paire_unique unique (restaurant_a, restaurant_b),
  constraint doublons_paire_ordonnee check (restaurant_a < restaurant_b)
);

comment on table public.doublons_suspects is
  'Suggestions de doublons. La fusion est TOUJOURS manuelle : noms similaires ≠ doublon (exigence du cahier des charges).';

create table if not exists public.journal_modifications (
  id                bigserial primary key,
  table_nom         text not null,
  enregistrement_id text not null,
  action            text not null check (action in ('insert', 'update', 'delete')),
  avant             jsonb,
  apres             jsonb,
  acteur            text,
  source            text,
  created_at        timestamptz not null default now()
);

create index if not exists idx_journal_table on public.journal_modifications(table_nom, enregistrement_id, created_at desc);

create or replace function public.journaliser()
returns trigger
language plpgsql
security definer
as $$
declare
  v_id text;
begin
  v_id := coalesce(
    (case when tg_op = 'DELETE' then (to_jsonb(old) ->> 'id') else (to_jsonb(new) ->> 'id') end),
    'inconnu'
  );

  insert into public.journal_modifications (table_nom, enregistrement_id, action, avant, apres, acteur, source)
  values (
    tg_table_name,
    v_id,
    lower(tg_op),
    case when tg_op = 'INSERT' then null else to_jsonb(old) end,
    case when tg_op = 'DELETE' then null else to_jsonb(new) end,
    current_user,
    current_setting('dekkfood.source_modification', true)
  );

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists trg_journal_restaurants on public.restaurants;
create trigger trg_journal_restaurants
  after insert or update or delete on public.restaurants
  for each row execute function public.journaliser();

drop trigger if exists trg_journal_plats on public.plats;
create trigger trg_journal_plats
  after insert or update or delete on public.plats
  for each row execute function public.journaliser();
