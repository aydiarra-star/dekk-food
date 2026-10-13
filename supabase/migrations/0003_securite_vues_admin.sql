-- =============================================================================
-- DEKK FOOD / DAKA FOOD — Migration 0003
-- Sécurité (RLS, rôles), détection des doublons, vues d'administration
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Rôles d'administration
-- -----------------------------------------------------------------------------
create table if not exists public.utilisateurs_admin (
  id                uuid primary key,
  email             text not null unique,
  nom               text,
  role              text not null default 'verificateur'
                    check (role in ('admin', 'editeur', 'moderateur', 'verificateur', 'restaurateur', 'lecteur')),
  restaurant_id     uuid references public.restaurants(id) on delete set null,
  actif             boolean not null default true,
  created_at        timestamptz not null default now(),
  -- Un compte « restaurateur » est obligatoirement rattaché à un établissement.
  constraint utilisateurs_admin_restaurateur_check check (role <> 'restaurateur' or restaurant_id is not null)
);

comment on table public.utilisateurs_admin is
  'Rôles d''administration. Le rôle « restaurateur » ne donne accès qu''à SA fiche et ne peut pas auto-attribuer le badge « vérifié ».';

-- Identité de l'utilisateur courant : auth.uid() sous Supabase, paramètre de
-- session ailleurs (tests locaux, scripts d'import).
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'auth') then
    execute $fn$
      create or replace function public.utilisateur_courant() returns uuid
      language sql stable as $body$ select auth.uid() $body$;
    $fn$;
  else
    create or replace function public.utilisateur_courant() returns uuid
    language sql stable as $body$
      select nullif(current_setting('dekkfood.utilisateur_id', true), '')::uuid
    $body$;
  end if;
end;
$$;

create or replace function public.role_courant()
returns text
language sql
stable
as $$
  select u.role
  from public.utilisateurs_admin u
  where u.id = public.utilisateur_courant() and u.actif
  limit 1;
$$;

create or replace function public.est_administrateur()
returns boolean
language sql
stable
as $$
  select coalesce(public.role_courant() in ('admin', 'editeur'), false);
$$;

-- -----------------------------------------------------------------------------
-- 2. Sécurité au niveau des lignes (RLS)
-- -----------------------------------------------------------------------------
-- Sur Supabase, les rôles anon / authenticated / service_role existent déjà.
-- Ailleurs (PostgreSQL nu, instance de test), ils sont créés ici afin que les
-- politiques de sécurité soient appliquées de la même manière partout.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end;
$$;

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select on all tables in schema public to anon;
grant usage, select on all sequences in schema public to authenticated, anon;

do $$
declare
  t text;
  lecture_publique text[] := array[
    'regions', 'departements', 'communes', 'quartiers', 'types_etablissement',
    'categories_culinaires', 'services', 'allergenes', 'regimes_alimentaires',
    'sources', 'images', 'horaires', 'horaires_exceptionnels', 'zones_livraison',
    'contacts', 'menus', 'menu_sections', 'plats', 'plat_allergenes', 'plat_regimes',
    'plat_promotions', 'etablissement_services', 'etablissement_categories',
    'etablissement_sources', 'etablissement_exploitation', 'entreprises', 'gestionnaires'
  ];
  admin_seulement text[] := array[
    'utilisateurs_admin', 'import_lots', 'import_lignes', 'doublons_suspects',
    'journal_modifications', 'verifications', 'signalements', 'demandes_correction',
    'revendications'
  ];
begin
  foreach t in array lecture_publique loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "%s_lecture_publique" on public.%I', t, t);
    execute format('create policy "%s_lecture_publique" on public.%I for select to anon, authenticated using (true)', t, t);
    execute format('drop policy if exists "%s_ecriture_admin" on public.%I', t, t);
    execute format('create policy "%s_ecriture_admin" on public.%I for all to authenticated using (public.est_administrateur()) with check (public.est_administrateur())', t, t);
  end loop;

  foreach t in array admin_seulement loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "%s_lecture_admin" on public.%I', t, t);
    execute format('create policy "%s_lecture_admin" on public.%I for select to authenticated using (public.est_administrateur() or (select public.role_courant()) = ''moderateur'')', t, t);
    execute format('drop policy if exists "%s_ecriture_admin" on public.%I', t, t);
    execute format('create policy "%s_ecriture_admin" on public.%I for all to authenticated using (public.est_administrateur()) with check (public.est_administrateur())', t, t);
  end loop;
end;
$$;

-- Établissements : lecture publique uniquement des fiches publiées et non définitivement fermées.
alter table public.restaurants enable row level security;

drop policy if exists "restaurants_lecture_publique" on public.restaurants;
create policy "restaurants_lecture_publique" on public.restaurants
  for select to anon, authenticated
  using (est_publication_visible = true and statut <> 'ferme_definitivement');

drop policy if exists "restaurants_ecriture_admin" on public.restaurants;
create policy "restaurants_ecriture_admin" on public.restaurants
  for all to authenticated
  using (public.est_administrateur())
  with check (public.est_administrateur());

-- Le restaurateur propriétaire de la fiche peut la lire et la modifier,
-- mais JAMAIS élever son propre niveau de vérification.
drop policy if exists "restaurants_lecture_restaurateur" on public.restaurants;
create policy "restaurants_lecture_restaurateur" on public.restaurants
  for select to authenticated
  using (id = (select u.restaurant_id from public.utilisateurs_admin u
               where u.id = public.utilisateur_courant() and u.actif and u.role = 'restaurateur'));

drop policy if exists "restaurants_ecriture_restaurateur" on public.restaurants;
create policy "restaurants_ecriture_restaurateur" on public.restaurants
  for update to authenticated
  using (id = (select u.restaurant_id from public.utilisateurs_admin u
               where u.id = public.utilisateur_courant() and u.actif and u.role = 'restaurateur'))
  with check (
    id = (select u.restaurant_id from public.utilisateurs_admin u
          where u.id = public.utilisateur_courant() and u.actif and u.role = 'restaurateur')
    and niveau_verification = (select r.niveau_verification from public.restaurants r where r.id = id)
  );

-- Avis : lecture des avis publiés uniquement, dépôt public possible.
alter table public.avis enable row level security;

drop policy if exists "avis_lecture_publiee" on public.avis;
create policy "avis_lecture_publiee" on public.avis
  for select to anon, authenticated
  using (statut = 'publie' or public.est_administrateur());

drop policy if exists "avis_depot_public" on public.avis;
create policy "avis_depot_public" on public.avis
  for insert to anon, authenticated
  with check (statut = 'en_attente' and note between 1 and 5);

drop policy if exists "avis_ecriture_admin" on public.avis;
create policy "avis_ecriture_admin" on public.avis
  for all to authenticated
  using (public.est_administrateur())
  with check (public.est_administrateur());

-- Signalements, corrections et revendications : dépôt public, traitement réservé à l'administration.
do $$
declare
  t text;
begin
  foreach t in array array['signalements', 'demandes_correction', 'revendications'] loop
    execute format('drop policy if exists "%s_depot_public" on public.%I', t, t);
    execute format($f$create policy "%s_depot_public" on public.%I for insert to anon, authenticated
                     with check (statut in ('nouveau', 'nouvelle', 'en_attente'))$f$, t, t);
  end loop;
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. Détection des doublons (suggestion, jamais de fusion automatique)
-- -----------------------------------------------------------------------------
-- Champ normalisé du téléphone (chiffres uniquement), utile au dédoublonnage.
create or replace function public.cle_nom_tel(valeur text)
returns text
language sql
immutable
as $$
  select nullif(
    case
      when length(regexp_replace(coalesce(valeur, ''), '[^0-9]', '', 'g')) >= 9
        then right(regexp_replace(coalesce(valeur, ''), '[^0-9]', '', 'g'), 9)
      else null
    end, '');
$$;

create or replace function public.detecter_doublons(
  p_seuil numeric default 0.62,
  p_distance_m integer default 150,
  p_seuil_contact numeric default 0.50
)
returns integer
language plpgsql
security definer
as $$
declare
  inseres integer := 0;
begin
  with candidats as (
    select
      a.id as a_id,
      b.id as b_id,
      -- Ressemblance de nom calculée sur les mots significatifs uniquement :
      -- « Restaurant Le Lagon » et « Restaurant La Douma » ne sont pas proches.
      -- Score de nom calculé par public.similarite_noms : mêmes règles que le
      -- moteur Python (mots significatifs, accents retirés, contenance plafonnée).
      public.similarite_noms(a.name, b.name) as score_nom,
      -- Pénalités identiques au pipeline Python : région divergente (-0.20),
      -- sinon commune divergente (-0.15) ; aucune pénalité si l'information manque.
      (a.region_id is not null and b.region_id is not null and a.region_id is distinct from b.region_id)
        as regions_differentes,
      (a.commune_id is not null and b.commune_id is not null and a.commune_id is distinct from b.commune_id)
        as communes_differentes,
      array_remove(array[
        case when a.site_web is not null and a.site_web = b.site_web then 'site_web_identique' end,
        case when public.cle_nom_tel(a.whatsapp) is not null
                  and public.cle_nom_tel(a.whatsapp) = public.cle_nom_tel(b.whatsapp) then 'whatsapp_identique' end,
        case when public.cle_nom_tel(a.phone) is not null
                  and public.cle_nom_tel(a.phone) = public.cle_nom_tel(b.phone) then 'telephone_identique' end,
        case when a.latitude is not null and b.latitude is not null
                  and public.distance_metres(a.latitude, a.longitude, b.latitude, b.longitude) < p_distance_m
             then 'gps_proche' end,
        case when public.cle_nom(a.neighborhood) is not null
                  and public.cle_nom(a.neighborhood) = public.cle_nom(b.neighborhood) then 'quartier_identique' end,
        -- Une adresse générique (« Ngor, Dakar ») ne prouve rien : l'égalité
        -- n'est retenue que si les deux libellés désignent une voie identifiable.
        case when public.cle_nom(a.address) is not null
                  and public.cle_nom(a.address) = public.cle_nom(b.address)
                  and (
                    a.address ~ '[0-9]'
                    or public.cle_nom(a.address) ~ '(rue|avenue|av|boulevard|bd|route|rte|rondpoint|plac|impasse|allee|cite|villa|km)'
                  )
                  and (
                    b.address ~ '[0-9]'
                    or public.cle_nom(b.address) ~ '(rue|avenue|av|boulevard|bd|route|rte|rondpoint|plac|impasse|allee|cite|villa|km)'
                  )
             then 'adresse_identique' end
      ], null) as motifs
    from public.restaurants a
    join public.restaurants b
      on a.id < b.id
     and (
       public.similarite_noms(a.name, b.name) >= p_seuil
       -- OU coordonnée professionnelle partagée : signal indépendant du nom de l'enseigne
       or (a.site_web is not null and a.site_web = b.site_web)
       or (public.cle_nom_tel(a.whatsapp) is not null
           and public.cle_nom_tel(a.whatsapp) = public.cle_nom_tel(b.whatsapp))
       or (public.cle_nom_tel(a.phone) is not null
           and public.cle_nom_tel(a.phone) = public.cle_nom_tel(b.phone))
     )
  ),
  scores as (
    select
      a_id,
      b_id,
      motifs,
      least(1.0, greatest(
        score_nom
        + 0.30 * (case when 'site_web_identique' = any(motifs) then 1 else 0 end)
        + 0.25 * (case when 'whatsapp_identique' = any(motifs) then 1 else 0 end)
        + 0.20 * (case when 'telephone_identique' = any(motifs) then 1 else 0 end)
        + 0.15 * (case when 'gps_proche' = any(motifs) then 1 else 0 end)
        + 0.10 * (case when 'adresse_identique' = any(motifs) then 1 else 0 end)
        + 0.05 * (case when 'quartier_identique' = any(motifs) then 1 else 0 end)
        -- Une seule pénalité : région divergente (-0.20), sinon commune (-0.15).
        - (case when regions_differentes then 0.20 when communes_differentes then 0.15 else 0 end),
        -- Une coordonnée partagée est un signal fort même si les noms diffèrent
        case when motifs && array['site_web_identique', 'whatsapp_identique', 'telephone_identique']
             then p_seuil_contact else 0 end
      )) as score
    from candidats
  ),
  inseres_cte as (
    insert into public.doublons_suspects (restaurant_a, restaurant_b, score, motifs)
    select a_id, b_id, round((score * 100)::numeric, 2), motifs
    from scores
    where score >= p_seuil
       or (score >= p_seuil_contact
           and motifs && array['site_web_identique', 'whatsapp_identique', 'telephone_identique'])
    on conflict (restaurant_a, restaurant_b) do nothing
    returning 1
  )
  select count(*) into inseres from inseres_cte;

  return inseres;
end;
$$;

comment on function public.detecter_doublons is
  'Alimente doublons_suspects. Ne fusionne rien : la décision reste humaine (exigence « ne pas fusionner deux établissements aux noms similaires »).';

-- -----------------------------------------------------------------------------
-- 4. Vues d'administration et de publication
-- -----------------------------------------------------------------------------
create or replace view public.v_couverture_par_region as
select
  r.id                                   as region_id,
  r.code                                 as region_code,
  r.nom                                  as region,
  count(e.id)                            as fiches,
  count(e.id) filter (where e.est_publication_visible)                        as fiches_publiees,
  count(e.id) filter (where e.niveau_verification = 'verifie')                as fiches_verifiees,
  count(e.id) filter (where e.gps_verifie)                                    as fiches_gps_verifie,
  count(e.id) filter (where e.derniere_verification_le is not null)           as fiches_verifiees_recemment,
  max(e.derniere_verification_le)                                             as derniere_verification_le
from public.regions r
left join public.restaurants e on e.region_id = r.id
group by r.id, r.code, r.nom
order by r.id;

create or replace view public.v_couverture_par_ville as
select
  coalesce(co.nom, e.ville_libre, 'Non renseignée')  as ville,
  reg.nom                                            as region,
  count(e.id)                                        as fiches,
  count(e.id) filter (where e.est_publication_visible) as fiches_publiees
from public.restaurants e
left join public.communes co on co.id = e.commune_id
left join public.departements d on d.id = e.departement_id
left join public.regions reg on reg.id = e.region_id
group by 1, 2
order by 3 desc;

create or replace view public.v_couverture_par_categorie as
select
  tc.libelle          as type_etablissement,
  e.cuisine_type      as categorie_culinaire,
  count(*)            as fiches
from public.restaurants e
left join public.types_etablissement tc on tc.id = e.type_etablissement_id
group by 1, 2
order by 3 desc;

create or replace view public.v_qualite_catalogue as
select
  (select count(*) from public.restaurants)                                        as fiches_total,
  (select count(*) from public.restaurants where est_publication_visible)          as fiches_publiees,
  (select count(*) from public.restaurants where adresse_complete is not null)     as fiches_adresse_confirmee,
  (select count(*) from public.restaurants where gps_verifie)                      as fiches_gps_confirme,
  (select count(distinct i.restaurant_id) from public.images i
     where i.correspondance_verifiee and not i.est_illustration_generique)         as fiches_photos_autorisees,
  (select count(distinct m.restaurant_id) from public.menus m where m.statut = 'confirme') as fiches_menu_confirme,
  (select count(*) from public.menus)                                              as menus_total,
  (select count(distinct c.restaurant_id) from public.contacts c where c.confirme)  as fiches_contacts_confirme,
  (select count(distinct ex.restaurant_id) from public.etablissement_exploitation ex
     where ex.statut_confirmation = 'confirme')                                    as fiches_proprietaire_confirme,
  (select count(*) from public.entreprises)                                        as entreprises_identifiees,
  (select count(*) from public.restaurants where niveau_verification = 'verifie')   as fiches_verifiees,
  (select count(*) from public.restaurants where niveau_verification = 'partiellement_verifie') as fiches_partielles,
  (select count(*) from public.restaurants where niveau_verification = 'a_confirmer')          as fiches_a_confirmer,
  (select count(*) from public.restaurants where statut = 'a_verifier')             as fiches_statut_a_verifier,
  (select count(*) from public.restaurants where statut = 'ferme_temporairement')   as fiches_fermeture_a_verifier,
  (select count(*) from public.restaurants where derniere_verification_le is null) as fiches_jamais_verifiees,
  (select count(*) from public.restaurants
     where derniere_verification_le is not null
       and derniere_verification_le < current_date - interval '12 months') as fiches_obsoletes,
  (select count(*) from public.doublons_suspects where statut = 'a_examiner')       as doublons_a_examiner,
  (select count(*) from public.avis where statut = 'en_attente')                    as avis_a_moderer,
  (select count(*) from public.signalements where statut = 'nouveau')               as signalements_a_traiter,
  (select count(*) from public.revendications where statut in ('en_attente', 'en_verification')) as revendications_a_traiter,
  (select coalesce(max(updated_at), now()) from public.restaurants)                 as derniere_maj_fond
;

create or replace view public.v_file_travail as
select
  e.id,
  e.numero_fiche,
  e.name,
  coalesce(co.nom, e.ville_libre)  as ville,
  reg.nom                          as region,
  e.statut,
  e.niveau_verification,
  e.derniere_verification_le,
  (
    (case when e.region_id is null then 3 else 0 end) +
    (case when e.commune_id is null and e.ville_libre is null then 2 else 0 end) +
    (case when e.adresse_complete is null then 2 else 0 end) +
    (case when e.latitude is null then 2 else 0 end) +
    (case when not exists (select 1 from public.contacts c where c.restaurant_id = e.id) then 2 else 0 end) +
    (case when not exists (select 1 from public.horaires h where h.restaurant_id = e.id) then 1 else 0 end) +
    (case when not exists (select 1 from public.menus m where m.restaurant_id = e.id) then 2 else 0 end) +
    (case when not exists (select 1 from public.images i where i.restaurant_id = e.id and not i.est_illustration_generique) then 1 else 0 end) +
    (case when e.derniere_verification_le is null then 2
          when e.derniere_verification_le < current_date - interval '12 months' then 1 else 0 end)
  ) as priorite
from public.restaurants e
left join public.communes co on co.id = e.commune_id
left join public.regions reg on reg.id = e.region_id
order by priorite desc, e.name;

comment on view public.v_file_travail is
  'File de travail de l''administration : les fiches les plus incomplètes d''abord, avec un score de priorité explicite.';

create or replace view public.v_etablissements_publics as
select
  e.id,
  e.numero_fiche,
  coalesce(e.nom_commercial, e.name)  as nom,
  e.name                              as nom_officiel,
  e.slug,
  e.cuisine_type,
  e.description_courte,
  e.description_longue,
  e.statut,
  e.niveau_verification,
  e.derniere_verification_le,
  reg.nom                             as region,
  d.nom                               as departement,
  co.nom                              as commune,
  q.nom                               as quartier,
  e.neighborhood                      as quartier_libre,
  e.ville_libre,
  e.address                           as adresse,
  e.adresse_complete,
  e.latitude,
  e.longitude,
  e.gps_verifie,
  e.points_de_repere,
  e.phone,
  e.whatsapp,
  e.site_web,
  e.facebook,
  e.instagram,
  e.fourchette_prix_min,
  e.fourchette_prix_max,
  e.devise,
  e.ambiance,
  e.modes_paiement,
  e.accessibilite,
  e.image_principale_url,
  e.source_principale_url,
  e.date_collecte,
  e.updated_at
from public.restaurants e
left join public.regions reg on reg.id = e.region_id
left join public.departements d on d.id = e.departement_id
left join public.communes co on co.id = e.commune_id
left join public.quartiers q on q.id = e.quartier_id
where e.est_publication_visible = true and e.statut <> 'ferme_definitivement';

create or replace view public.v_plats_publics as
select
  p.id,
  p.restaurant_id,
  e.name            as etablissement,
  p.nom,
  p.description,
  p.categorie,
  p.prix,
  p.devise,
  p.taille_portion,
  p.disponibilite,
  p.statut_confirmation,
  p.source_url,
  p.derniere_maj,
  m.nom             as menu,
  m.type            as menu_type,
  (select i.url from public.images i
     where i.plat_id = p.id and not i.est_illustration_generique
     order by i.ordre limit 1) as image_url
from public.plats p
join public.restaurants e on e.id = p.restaurant_id
left join public.menus m on m.id = p.menu_id
where p.est_actif and e.est_publication_visible;

create or replace view public.v_doublons_a_examiner as
select
  d.id,
  d.score,
  d.motifs,
  a.name as etablissement_a,
  a.id   as id_a,
  b.name as etablissement_b,
  b.id   as id_b,
  d.created_at
from public.doublons_suspects d
join public.restaurants a on a.id = d.restaurant_a
join public.restaurants b on b.id = d.restaurant_b
where d.statut = 'a_examiner'
order by d.score desc;

-- -----------------------------------------------------------------------------
-- 5. Stockage des images (uniquement si l'extension storage est disponible)
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    begin
      insert into storage.buckets (id, name, public)
      values ('catalogue-images', 'catalogue-images', true)
      on conflict (id) do nothing;
    exception when others then
      raise notice 'Bucket catalogue-images non créé automatiquement : %', sqlerrm;
    end;
  else
    raise notice 'Schéma storage absent (instance non Supabase) : création du bucket ignorée.';
  end if;
end;
$$;
