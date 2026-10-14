-- =============================================================================
-- DEKK FOOD / DAKA FOOD — Migration 0007
-- Durcissement des vues internes, des privilèges de rôles et des fonctions
-- =============================================================================
-- DÉFAUTS CORRIGÉS
--   1. Dans 0004, 0005 et 0006, les vues internes (`v_publication_catalogue`,
--      `v_fiches_a_valider`, `v_cloisonnement_public`, `v_acces_comptes`)
--      recevaient `GRANT SELECT ... TO authenticated` et n'activaient pas
--      `security_invoker = true`. En PostgreSQL, une vue s'exécute par défaut
--      avec les droits de son propriétaire (`postgres`, qui contourne la RLS) :
--      n'importe quel compte authentifié ordinaire, compte inactif ou
--      restaurateur pouvait donc lire les emails, rôles et états des comptes
--      (`v_acces_comptes`) ainsi que les identifiants, noms, motifs de
--      non-publication et compteurs des fiches non publiées
--      (`v_cloisonnement_public`, `v_publication_catalogue`).
--   2. Les vues créées en 0003 (`v_couverture_par_region`,
--      `v_couverture_par_ville`, `v_couverture_par_categorie`,
--      `v_qualite_catalogue`, `v_file_travail`, `v_doublons_a_examiner`,
--      `v_etablissements_publics`, `v_plats_publics`) n'avaient ni
--      `security_invoker = true`, ni `REVOKE` explicite protégeant contre un
--      `GRANT ... ON ALL TABLES` ou des `DEFAULT PRIVILEGES` hérités.
--   3. Les fonctions `SECURITY DEFINER` `public.detecter_doublons` et
--      `public.journaliser` n'avaient pas de `search_path` figé et conservaient
--      des droits `EXECUTE` ouverts à `PUBLIC` / `anon` / `authenticated`.
--
-- PRINCIPE DE LA CORRECTION (défense en profondeur compatible Supabase / PostgREST)
--   • Compatibilité Supabase Auth / PostgREST : sous Supabase, tout utilisateur
--     connecté (ordinaire, restaurateur ou administrateur) reçoit un JWT dont le
--     claim `role` vaut `authenticated` et le claim `sub` vaut l'UUID du compte
--     (`auth.uid()`). Un administrateur réel se connecte donc sous le rôle
--     PostgreSQL `authenticated` (sans jamais embarquer `service_role` dans le
--     client Flutter ou le navigateur) et est identifié par sa présence active
--     dans `public.utilisateurs_admin` (`role in ('admin', 'editeur')` et
--     `actif = true`).
--   • Révocation totale (`REVOKE ALL`) sur les 10 vues internes pour `PUBLIC`,
--     `anon` et `restaurateur` ; attribution du seul droit `SELECT` (aucun droit
--     d'écriture) à `authenticated`, `administrateur` et `service_role`.
--   • Activation de `security_invoker = true` et `security_barrier = true` sur
--     les 12 vues du schéma `public` : aucune vue ne s'exécute plus sous les
--     droits de son propriétaire (`postgres`), la RLS des tables sources
--     s'applique toujours à l'appelant.
--   • Garde bloquante `public.exiger_acces_administration()` (compilée par
--     PostgreSQL en `One-Time Filter` avant tout parcours de table) dans chacune
--     des 10 vues internes : tout appel par un compte `authenticated` ordinaire,
--     un compte `lecteur`, un compte inactif ou un `restaurateur` lève
--     immédiatement une erreur PostgreSQL `SQLSTATE 42501`
--     (`insufficient_privilege`), tandis qu'un administrateur actif (`auth.uid()`
--     actif dans `utilisateurs_admin`) est autorisé sous `authenticated` comme
--     sous `administrateur`.
--   • Préservation des parcours publics : `v_etablissements_publics` et
--     `v_plats_publics` restent lisibles par `anon` et `authenticated` avec
--     `security_invoker = true` et filtrage strict des fiches publiées.
--   • Durcissement des fonctions `SECURITY DEFINER` et d'administration :
--     `search_path = public, pg_temp` partout, `EXECUTE` révoqué pour `PUBLIC`,
--     `anon` et `restaurateur`, et garde `exiger_acces_administration()` en
--     entrée des fonctions d'administration.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Rôles PostgreSQL dédiés : séparation compte ordinaire / restaurateur / admin
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'administrateur') then
    create role administrateur nologin inherit in role authenticated;
  else
    grant authenticated to administrateur;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'restaurateur') then
    create role restaurateur nologin inherit in role authenticated;
  else
    grant authenticated to restaurateur;
  end if;
end;
$$;

grant usage on schema public to administrateur, restaurateur, service_role;
grant select, insert, update, delete on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to administrateur, restaurateur, service_role;

-- -----------------------------------------------------------------------------
-- 2. Identité Supabase / PostgREST et garde d'administration active
-- -----------------------------------------------------------------------------
-- Lecture unifiée de l'identité courante :
--   1. `auth.uid()` sur une instance Supabase ;
--   2. claims JWT posés par PostgREST (`request.jwt.claim.sub` ou
--      `request.jwt.claims` -> `sub`) ;
--   3. paramètre de session `dekkfood.utilisateur_id` (harnais de test SQL).
create or replace function public.utilisateur_courant()
returns uuid
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
declare
  v_uid uuid;
  v_sub text;
  v_claims text;
begin
  if to_regprocedure('auth.uid()') is not null then
    execute 'select auth.uid()' into v_uid;
    if v_uid is not null then
      return v_uid;
    end if;
  end if;

  v_sub := nullif(btrim(current_setting('request.jwt.claim.sub', true)), '');
  if v_sub is not null then
    return v_sub::uuid;
  end if;

  v_claims := nullif(btrim(current_setting('request.jwt.claims', true)), '');
  if v_claims is not null then
    v_sub := nullif(btrim(v_claims::jsonb ->> 'sub'), '');
    if v_sub is not null then
      return v_sub::uuid;
    end if;
  end if;

  v_sub := nullif(btrim(current_setting('dekkfood.utilisateur_id', true)), '');
  if v_sub is not null then
    return v_sub::uuid;
  end if;

  return null;
end;
$$;

comment on function public.utilisateur_courant() is
  'Identifiant UUID de l''utilisateur courant : auth.uid() sous Supabase, claim JWT sub sous PostgREST, ou dekkfood.utilisateur_id en test SQL.';

create or replace function public.exiger_acces_administration()
returns boolean
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
declare
  v_role_effectif text := coalesce(nullif(current_setting('role', true), 'none'), current_user);
begin
  -- Un rôle explicitement positionné à `restaurateur` ou `anon` n'est jamais
  -- autorisé à consulter une vue d'administration, même si un identifiant
  -- résiduel était présent en session.
  if v_role_effectif in ('anon', 'restaurateur') then
    raise exception 'Accès refusé : le rôle % n''est pas autorisé à accéder aux vues ou opérations d''administration.',
      v_role_effectif
      using errcode = '42501';
  end if;

  if public.est_administrateur()
     or (
       public.utilisateur_courant() is null
       and exists (
         select 1
         from pg_catalog.pg_roles
         where rolname = v_role_effectif
           and (rolsuper or rolbypassrls)
       )
     ) then
    return true;
  end if;

  raise exception 'Accès refusé : vue ou opération réservée à l''administration active (rôle : %, utilisateur : %).',
    v_role_effectif, coalesce(public.utilisateur_courant()::text, 'aucun')
    using errcode = '42501';
end;
$$;

comment on function public.exiger_acces_administration() is
  'Vérifie que l''appelant est un administrateur actif (admin ou editeur dans utilisateurs_admin, ou service_role/superutilisateur). Lève SQLSTATE 42501 sinon.';

-- La table des comptes (`utilisateurs_admin`) ne doit être lisible que par
-- l'administration (`admin`, `editeur`), jamais par un modérateur ni un tiers.
drop policy if exists "utilisateurs_admin_lecture_admin" on public.utilisateurs_admin;
create policy "utilisateurs_admin_lecture_admin" on public.utilisateurs_admin
  for select to authenticated
  using (public.est_administrateur());

-- Un restaurateur ne peut modifier que les données descriptives de SA fiche :
-- il ne peut ni s'attribuer un niveau de vérification, ni s'auto-publier, ni
-- effacer le motif de non-publication, ni altérer les champs de validation.
-- En PostgreSQL, une sous-requête dans WITH CHECK voit déjà la nouvelle ligne :
-- la comparaison OLD / NEW doit donc être assurée par un déclencheur BEFORE UPDATE.
drop policy if exists "restaurants_ecriture_restaurateur" on public.restaurants;
create policy "restaurants_ecriture_restaurateur" on public.restaurants
  for update to authenticated
  using (id = public.etablissement_du_restaurateur())
  with check (id = public.etablissement_du_restaurateur());

create or replace function public.controler_modification_restaurant()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_role_effectif text := coalesce(nullif(current_setting('role', true), 'none'), current_user);
begin
  if public.est_administrateur()
     or (
       public.utilisateur_courant() is null
       and exists (
         select 1
         from pg_catalog.pg_roles
         where rolname = v_role_effectif
           and (rolsuper or rolbypassrls)
       )
     ) then
    return new;
  end if;

  if new.niveau_verification is distinct from old.niveau_verification
     or new.est_publication_visible is distinct from old.est_publication_visible
     or new.motif_non_publication is distinct from old.motif_non_publication
     or new.statut_validation is distinct from old.statut_validation
     or new.validation_par is distinct from old.validation_par
     or new.validation_le is distinct from old.validation_le
     or new.derniere_verification_le is distinct from old.derniere_verification_le
     or new.commentaire_verification is distinct from old.commentaire_verification then
    raise exception 'Modification refusée : les champs de publication, de validation et de niveau de vérification sont réservés à l''administration.'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

comment on function public.controler_modification_restaurant() is
  'Interdit à tout rôle non-administrateur (notamment restaurateur) de modifier niveau_verification, est_publication_visible, motif_non_publication ou les colonnes de validation.';

drop trigger if exists trg_restaurants_controle_modification on public.restaurants;
create trigger trg_restaurants_controle_modification
  before update on public.restaurants
  for each row execute function public.controler_modification_restaurant();

-- -----------------------------------------------------------------------------
-- 3. Vues de contrôle et d'administration (security_invoker + garde + privilèges)
-- -----------------------------------------------------------------------------
create or replace view public.v_couverture_par_region
with (security_invoker = true, security_barrier = true) as
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
where public.exiger_acces_administration()
group by r.id, r.code, r.nom
order by r.id;

create or replace view public.v_couverture_par_ville
with (security_invoker = true, security_barrier = true) as
select
  coalesce(co.nom, e.ville_libre, 'Non renseignée')  as ville,
  reg.nom                                            as region,
  count(e.id)                                        as fiches,
  count(e.id) filter (where e.est_publication_visible) as fiches_publiees
from public.restaurants e
left join public.communes co on co.id = e.commune_id
left join public.departements d on d.id = e.departement_id
left join public.regions reg on reg.id = e.region_id
where public.exiger_acces_administration()
group by 1, 2
order by 3 desc;

create or replace view public.v_couverture_par_categorie
with (security_invoker = true, security_barrier = true) as
select
  tc.libelle          as type_etablissement,
  e.cuisine_type      as categorie_culinaire,
  count(*)            as fiches
from public.restaurants e
left join public.types_etablissement tc on tc.id = e.type_etablissement_id
where public.exiger_acces_administration()
group by 1, 2
order by 3 desc;

create or replace view public.v_qualite_catalogue
with (security_invoker = true, security_barrier = true) as
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
where public.exiger_acces_administration();

create or replace view public.v_file_travail
with (security_invoker = true, security_barrier = true) as
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
where public.exiger_acces_administration()
order by priorite desc, e.name;

create or replace view public.v_doublons_a_examiner
with (security_invoker = true, security_barrier = true) as
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
  and public.exiger_acces_administration()
order by d.score desc;

create or replace view public.v_publication_catalogue
with (security_invoker = true, security_barrier = true) as
select
  e.id,
  e.numero_fiche,
  e.name                                   as nom,
  reg.nom                                  as region,
  e.est_publication_visible,
  e.motif_non_publication,
  e.niveau_verification,
  e.statut_validation,
  e.validation_par,
  e.validation_le,
  e.derniere_verification_le,
  (e.niveau_verification = 'information_indisponible') as information_indisponible
from public.restaurants e
left join public.regions reg on reg.id = e.region_id
where public.exiger_acces_administration()
order by e.est_publication_visible, e.name;

create or replace view public.v_fiches_a_valider
with (security_invoker = true, security_barrier = true) as
select
  e.id,
  e.numero_fiche,
  e.name                                   as nom,
  reg.nom                                  as region,
  e.niveau_verification,
  e.statut_validation,
  e.derniere_verification_le,
  (select count(*) from public.contacts c where c.restaurant_id = e.id)                    as contacts,
  exists (select 1 from public.contacts c where c.restaurant_id = e.id and c.confirme)     as contact_confirme,
  exists (select 1 from public.horaires h where h.restaurant_id = e.id)                    as horaires,
  exists (select 1 from public.menus m where m.restaurant_id = e.id)                       as menu,
  exists (select 1 from public.images i
           where i.restaurant_id = e.id and not i.est_illustration_generique)              as photo_authentique
from public.restaurants e
left join public.regions reg on reg.id = e.region_id
where e.statut_validation <> 'validee'
  and e.est_publication_visible
  and public.exiger_acces_administration()
order by contact_confirme desc, contacts desc, e.name;

create or replace view public.v_cloisonnement_public
with (security_invoker = true, security_barrier = true) as
select
  e.id,
  e.numero_fiche,
  e.name                                             as nom,
  e.est_publication_visible,
  coalesce(e.motif_non_publication, '')              as motif,
  (select count(*) from public.contacts c where c.restaurant_id = e.id)     as contacts,
  (select count(*) from public.menus m where m.restaurant_id = e.id)        as menus,
  (select count(*) from public.plats p where p.restaurant_id = e.id)        as plats,
  (select count(*) from public.images i where i.restaurant_id = e.id)       as images,
  (select count(*) from public.horaires h where h.restaurant_id = e.id)     as horaires,
  (select count(*) from public.etablissement_sources s where s.restaurant_id = e.id) as sources
from public.restaurants e
where public.exiger_acces_administration()
order by e.est_publication_visible, e.name;

create or replace view public.v_acces_comptes
with (security_invoker = true, security_barrier = true) as
select
  u.id,
  u.email,
  u.role,
  u.actif,
  u.restaurant_id,
  r.slug                              as etablissement,
  r.est_publication_visible,
  coalesce(u.role in ('admin', 'editeur'), false)   as acces_complet,
  (u.role = 'restaurateur' and u.restaurant_id is not null) as perimetre_restaurateur
from public.utilisateurs_admin u
left join public.restaurants r on r.id = u.restaurant_id
where public.exiger_acces_administration()
order by u.role, u.email;

-- Attribution stricte des privilèges sur les 10 vues internes :
-- - aucun accès pour PUBLIC, anon ou restaurateur ;
-- - SELECT seul (aucun INSERT/UPDATE/DELETE) pour authenticated (requis par
--   PostgREST lorsqu'un administrateur connecté présente un JWT Supabase de rôle
--   `authenticated`), administrateur et service_role ;
-- - tout compte `authenticated` non administrateur actif est bloqué dès l'entrée
--   de la vue par `One-Time Filter: public.exiger_acces_administration()`
--   (SQLSTATE 42501) et par `security_invoker = true`.
do $$
declare
  vue_interne text;
  vues_internes text[] := array[
    'v_couverture_par_region',
    'v_couverture_par_ville',
    'v_couverture_par_categorie',
    'v_qualite_catalogue',
    'v_file_travail',
    'v_doublons_a_examiner',
    'v_publication_catalogue',
    'v_fiches_a_valider',
    'v_cloisonnement_public',
    'v_acces_comptes'
  ];
begin
  foreach vue_interne in array vues_internes loop
    execute format(
      'revoke all on public.%I from public, anon, authenticated, restaurateur, administrateur, service_role',
      vue_interne
    );
    execute format(
      'grant select on public.%I to authenticated, administrateur, service_role',
      vue_interne
    );
  end loop;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Vues publiques (security_invoker + filtrage strict des fiches publiées)
-- -----------------------------------------------------------------------------
create or replace view public.v_etablissements_publics
with (security_invoker = true, security_barrier = true) as
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
where e.est_publication_visible = true
  and e.statut <> 'ferme_definitivement';

create or replace view public.v_plats_publics
with (security_invoker = true, security_barrier = true) as
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
where p.est_actif
  and e.est_publication_visible = true
  and e.statut <> 'ferme_definitivement';

revoke all on public.v_etablissements_publics from public, anon, authenticated, restaurateur, administrateur, service_role;
revoke all on public.v_plats_publics from public, anon, authenticated, restaurateur, administrateur, service_role;
grant select on public.v_etablissements_publics to anon, authenticated, restaurateur, administrateur, service_role;
grant select on public.v_plats_publics to anon, authenticated, restaurateur, administrateur, service_role;

-- -----------------------------------------------------------------------------
-- 5. Fonctions SECURITY DEFINER et d'administration : search_path et EXECUTE
-- -----------------------------------------------------------------------------
-- 5.1 detecter_doublons : réservée à l'administration, search_path figé.
create or replace function public.detecter_doublons(
  p_seuil numeric default 0.62,
  p_distance_m integer default 150,
  p_seuil_contact numeric default 0.50
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  inseres integer := 0;
begin
  perform public.exiger_acces_administration();

  with candidats as (
    select
      a.id as a_id,
      b.id as b_id,
      public.similarite_noms(a.name, b.name) as score_nom,
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
        - (case when regions_differentes then 0.20 when communes_differentes then 0.15 else 0 end),
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

-- 5.2 journaliser : trigger d'audit en SECURITY DEFINER, search_path figé.
create or replace function public.journaliser()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
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

-- 5.3 Fixation du search_path sur toutes les fonctions du schéma public.
alter function public.utilisateur_courant() set search_path = public, pg_temp;
alter function public.role_courant() set search_path = public, pg_temp;
alter function public.est_administrateur() set search_path = public, pg_temp;
alter function public.etablissement_du_restaurateur() set search_path = public, pg_temp;
alter function public.valider_fiche_par_controle(uuid, text, text, text) set search_path = public, pg_temp;
alter function public.devalider_fiche(uuid, text) set search_path = public, pg_temp;
alter function public.controler_revendication() set search_path = public, pg_temp;
alter function public.maj_horodatage() set search_path = public, pg_temp;
alter function public.distance_metres(double precision, double precision, double precision, double precision) set search_path = public, pg_temp;
alter function public.cle_nom(text) set search_path = public, pg_temp;
alter function public.cle_nom_significative(text) set search_path = public, pg_temp;
alter function public.similarite_chaines(text, text) set search_path = public, pg_temp;
alter function public.similarite_noms(text, text) set search_path = public, pg_temp;
alter function public.cle_nom_tel(text) set search_path = public, pg_temp;

-- 5.4 Droits EXECUTE stricts : aucune exposition à PUBLIC / anon / restaurateur,
--     compatibilité PostgREST (`authenticated` + garde `exiger_acces_administration()`
--     ou `est_administrateur()` qui lève une exception pour tout non-admin).
revoke all on function public.detecter_doublons(numeric, integer, numeric) from public, anon, authenticated, restaurateur;
grant execute on function public.detecter_doublons(numeric, integer, numeric) to authenticated, administrateur, service_role;

revoke all on function public.valider_fiche_par_controle(uuid, text, text, text) from public, anon, authenticated, restaurateur;
grant execute on function public.valider_fiche_par_controle(uuid, text, text, text) to authenticated, administrateur, service_role;

revoke all on function public.devalider_fiche(uuid, text) from public, anon, authenticated, restaurateur;
grant execute on function public.devalider_fiche(uuid, text) to authenticated, administrateur, service_role;

revoke all on function public.exiger_acces_administration() from public, anon, authenticated, restaurateur;
grant execute on function public.exiger_acces_administration() to authenticated, administrateur, service_role;

revoke all on function public.journaliser() from public, anon;
grant execute on function public.journaliser() to authenticated, restaurateur, administrateur, service_role;

revoke all on function public.controler_modification_restaurant() from public, anon;
grant execute on function public.controler_modification_restaurant() to authenticated, restaurateur, administrateur, service_role;

revoke all on function public.etablissement_du_restaurateur() from public, anon;
grant execute on function public.etablissement_du_restaurateur() to authenticated, restaurateur, administrateur, service_role;

revoke all on function public.role_courant() from public;
grant execute on function public.role_courant() to anon, authenticated, restaurateur, administrateur, service_role;

revoke all on function public.est_administrateur() from public;
grant execute on function public.est_administrateur() to anon, authenticated, restaurateur, administrateur, service_role;

revoke all on function public.utilisateur_courant() from public;
grant execute on function public.utilisateur_courant() to anon, authenticated, restaurateur, administrateur, service_role;
