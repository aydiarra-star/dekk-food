-- =============================================================================
-- DEKK FOOD / DAKA FOOD — Migration 0005
-- Cloisonnement public des données rattachées aux fiches non publiées
-- =============================================================================
-- DÉFAUT CORRIGÉ
--   La migration 0003 protège correctement la table `restaurants` (une fiche non
--   publiée n'est pas lisible par le public), mais les tables FILLES conservaient
--   une politique `for select ... using (true)` : n'importe quel visiteur pouvait
--   donc lire le téléphone, l'adresse, les contacts, les menus, les plats, les
--   images, les horaires ou les zones de livraison d'une fiche NON PUBLIÉE, en
--   interrogeant directement la table associée (ex.
--   `select * from public.contacts where restaurant_id = '<fiche non publiée>'`).
--
-- PRINCIPE DE LA CORRECTION (minimal et non cassant)
--   La visibilité publique d'une ligne fille suit celle de sa fiche parente.
--   La condition utilise un `exists (...)` sur la table parente : la politique
--   RLS DU PARENT s'applique alors naturellement, sans redéfinir les droits.
--   Conséquences, sans aucune politique supplémentaire à maintenir :
--     • visiteur anonyme   → voit les données des fiches publiées, et elles seules ;
--     • administrateur     → conserve l'accès complet (politique « for all » de 0003) ;
--     • restaurateur       → conserve l'accès à SA fiche, y compris non publiée,
--                            et perd l'accès aux fiches non publiées des autres ;
--     • autres comptes     → mêmes droits que le public.
--
-- Aucune donnée n'est supprimée ni déplacée : seules des politiques de lecture
-- sont redéfinies. Aucune ligne existante n'est modifiée par cette migration.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Politique publique des tables filles rattachées à un établissement
-- -----------------------------------------------------------------------------
do $$
declare
  cible record;
  -- Tables reliées à `restaurants` par leur propre colonne restaurant_id.
  directes text[] := array[
    'contacts', 'menus', 'plats', 'horaires', 'horaires_exceptionnels',
    'zones_livraison', 'etablissement_services', 'etablissement_categories',
    'etablissement_sources', 'etablissement_exploitation'
  ];
begin
  for cible in
    select unnest(directes) as table_fille
  loop
    execute format(
      'drop policy if exists "%s_lecture_publique" on public.%I',
      cible.table_fille, cible.table_fille
    );
    execute format(
      'create policy "%s_lecture_publique" on public.%I for select to anon, authenticated '
      'using (exists (select 1 from public.restaurants r where r.id = %I.restaurant_id))',
      cible.table_fille, cible.table_fille, cible.table_fille
    );
  end loop;
end;
$$;

comment on policy "contacts_lecture_publique" on public.contacts is
  'Un contact n''est public que si sa fiche est visible pour celui qui interroge (fiche publiée, ou sa propre fiche pour un restaurateur).';

-- `images` : rattachée soit à un établissement, soit directement à un plat.
do $$
begin
  drop policy if exists "images_lecture_publique" on public.images;
  create policy "images_lecture_publique" on public.images
    for select to anon, authenticated
    using (
      (restaurant_id is not null
        and exists (select 1 from public.restaurants r where r.id = images.restaurant_id))
      or (restaurant_id is null and plat_id is not null
        and exists (select 1 from public.plats p where p.id = images.plat_id))
    );

  -- `menu_sections` est rattachée à un menu.
  drop policy if exists "menu_sections_lecture_publique" on public.menu_sections;
  create policy "menu_sections_lecture_publique" on public.menu_sections
    for select to anon, authenticated
    using (exists (select 1 from public.menus m where m.id = menu_sections.menu_id));

  -- Les tables rattachées à un plat suivent la visibilité du plat.
  drop policy if exists "plat_allergenes_lecture_publique" on public.plat_allergenes;
  create policy "plat_allergenes_lecture_publique" on public.plat_allergenes
    for select to anon, authenticated
    using (exists (select 1 from public.plats p where p.id = plat_allergenes.plat_id));

  drop policy if exists "plat_regimes_lecture_publique" on public.plat_regimes;
  create policy "plat_regimes_lecture_publique" on public.plat_regimes
    for select to anon, authenticated
    using (exists (select 1 from public.plats p where p.id = plat_regimes.plat_id));

  drop policy if exists "plat_promotions_lecture_publique" on public.plat_promotions;
  create policy "plat_promotions_lecture_publique" on public.plat_promotions
    for select to anon, authenticated
    using (exists (select 1 from public.plats p where p.id = plat_promotions.plat_id));

  -- Informations d'exploitation (propriétaire, gérant, entreprise) : jamais
  -- exposées pour une fiche non publiée.
  drop policy if exists "entreprises_lecture_publique" on public.entreprises;
  create policy "entreprises_lecture_publique" on public.entreprises
    for select to anon, authenticated
    using (exists (select 1 from public.etablissement_exploitation e
                   where e.entreprise_id = entreprises.id));

  drop policy if exists "gestionnaires_lecture_publique" on public.gestionnaires;
  create policy "gestionnaires_lecture_publique" on public.gestionnaires
    for select to anon, authenticated
    using (
      exists (select 1 from public.etablissement_exploitation e
              where e.gestionnaire_id = gestionnaires.id)
      or exists (select 1 from public.entreprises en where en.id = gestionnaires.entreprise_id)
    );
end;
$$;

-- -----------------------------------------------------------------------------
-- 2. Avis : un avis publié ne doit pas rendre visible une fiche non publiée
-- -----------------------------------------------------------------------------
drop policy if exists "avis_lecture_publiee" on public.avis;
create policy "avis_lecture_publiee" on public.avis
  for select to anon, authenticated
  using (
    (statut = 'publie'
      and exists (select 1 from public.restaurants r where r.id = avis.restaurant_id))
    or public.est_administrateur()
  );

comment on policy "avis_lecture_publiee" on public.avis is
  'Un avis n''est public que s''il est modéré ET rattaché à une fiche visible par l''interrogateur.';

-- -----------------------------------------------------------------------------
-- 3. Vues d'administration : contrôle du cloisonnement et de la conservation
-- -----------------------------------------------------------------------------
create or replace view public.v_cloisonnement_public as
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
order by e.est_publication_visible, e.name;

comment on view public.v_cloisonnement_public is
  'Contrôle de conservation : chaque fiche apparaît avec son état de publication et le nombre de données rattachées. Une fiche non publiée doit afficher ici le même nombre de données rattachées qu''une fiche publiée : rien n''est supprimé, seulement non exposé. La lecture publique des tables filles est cloisonnée par les politiques RLS de la migration 0005.';

revoke all on public.v_cloisonnement_public from anon;
grant select on public.v_cloisonnement_public to authenticated;

-- -----------------------------------------------------------------------------
-- 4. Table héritée `menu_items` : RLS absente (fermeture d'une faille latente)
-- -----------------------------------------------------------------------------
-- 0003 a accordé « select » à anon sur TOUTES les tables du schéma. `menu_items`,
-- table héritée de la première version de l'application, ne figurait ni dans la
-- liste protégée ni dans la liste d'administration : elle était donc lisible par
-- n'importe quel visiteur, sans politique. Elle ne contient aucune ligne
-- aujourd'hui (faille latente, pas de fuite constatée), mais toute insertion
-- future serait publique. Elle est désormais réservée à l'administration :
-- le catalogue actuel utilise la table `plats`.
do $$
begin
  if exists (select 1 from information_schema.tables
             where table_schema = 'public' and table_name = 'menu_items') then
    execute 'alter table public.menu_items enable row level security';
    execute 'drop policy if exists "menu_items_lecture_admin" on public.menu_items';
    execute 'create policy "menu_items_lecture_admin" on public.menu_items '
            'for select to authenticated using (public.est_administrateur())';
    execute 'drop policy if exists "menu_items_ecriture_admin" on public.menu_items';
    execute 'create policy "menu_items_ecriture_admin" on public.menu_items '
            'for all to authenticated using (public.est_administrateur()) '
            'with check (public.est_administrateur())';
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- 5. Index de soutien
-- -----------------------------------------------------------------------------
-- Les politiques ajoutées interrogent les colonnes de rattachement : les index
-- existants sur ces colonnes suffisent (idx_* créés en 0001/0002), on complète
-- uniquement pour les tables d'exploitation si nécessaire.
create index if not exists idx_exploitation_entreprise on public.etablissement_exploitation(entreprise_id);
create index if not exists idx_exploitation_gestionnaire on public.etablissement_exploitation(gestionnaire_id);
