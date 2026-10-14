-- =============================================================================
-- DEKK FOOD / DAKA FOOD — Migration 0006
-- Correction des politiques d'administration et de restaurateur (récursion RLS)
-- =============================================================================
-- DÉFAUT CORRIGÉ (démontré par test, voir tools/tests/verifier_schema_postgres.py)
--   Les politiques posées en 0003 interrogent `public.utilisateurs_admin`, dont
--   les politiques appellent elles-mêmes `est_administrateur()` → `role_courant()`
--   → `utilisateurs_admin`. PostgreSQL détecte alors :
--     « infinite recursion detected in policy for relation "restaurants" »
--   Conséquence mesurée : dès qu'un compte d'administration OU de restaurateur
--   existe, TOUTE requête d'un rôle non-superutilisateur sur `restaurants` et sur
--   les tables rattachées échoue. Les accès « administrateur » et « restaurateur »
--   n'étaient donc pas seulement restreints : ils étaient inutilisables.
--   (Le défaut restait invisible en test tant que `utilisateurs_admin` était vide :
--   les politiques n'étaient jamais évaluées faute de lignes.)
--
-- CORRECTION (minimale, sans toucher aux données)
--   1. les fonctions d'identité lisent `utilisateurs_admin` en SECURITY DEFINER :
--      elles ne déclenchent plus la politique de cette table, donc plus de
--      récursion. Chacune ne renvoie que des informations relatives à
--      l'utilisateur courant : aucun élargissement de droits ;
--   2. le périmètre du restaurateur s'obtient par une fonction dédiée
--      `etablissement_du_restaurateur()`, au lieu d'une sous-requête filtrée par
--      une politique qui masquait justement la ligne recherchée ;
--   3. la contrainte « un restaurateur ne peut pas élever son niveau de
--      vérification » est rendue effective : la sous-requête référençait `id`
--      dans son propre périmètre (`r.id = id`, toujours vrai) et comparait donc
--      à une ligne arbitraire. Elle référence désormais explicitement la ligne
--      contrôlée.
--
-- Effet sur les données existantes : AUCUN. Cette migration ne contient que des
-- définitions de fonctions et de politiques ; aucune ligne n'est lue, écrite,
-- déplacée ni supprimée.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Identités : lecture de `utilisateurs_admin` hors politiques (fin de récursion)
-- -----------------------------------------------------------------------------
create or replace function public.role_courant()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select u.role
  from public.utilisateurs_admin u
  where u.id = public.utilisateur_courant() and u.actif
  limit 1;
$$;

comment on function public.role_courant() is
  'Rôle de l''utilisateur courant. SECURITY DEFINER : lit utilisateurs_admin sans repasser par ses politiques, ce qui évite la récursion infinie. Ne renvoie que le rôle de l''appelant.';

create or replace function public.est_administrateur()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.role_courant() in ('admin', 'editeur'), false);
$$;

comment on function public.est_administrateur() is
  'Vrai si l''utilisateur courant a un rôle d''administration. SECURITY DEFINER pour rester évaluable depuis les politiques (voir 0006).';

-- Périmètre du restaurateur : l'établissement auquel SON compte est rattaché.
create or replace function public.etablissement_du_restaurateur()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select u.restaurant_id
  from public.utilisateurs_admin u
  where u.id = public.utilisateur_courant()
    and u.actif
    and u.role = 'restaurateur'
  limit 1;
$$;

comment on function public.etablissement_du_restaurateur() is
  'Identifiant du seul établissement que l''utilisateur courant peut administrer en tant que restaurateur (null sinon). SECURITY DEFINER : renvoie uniquement le périmètre de l''appelant, jamais celui d''un autre compte.';

-- -----------------------------------------------------------------------------
-- 2. Politiques `restaurants` du restaurateur : périmètre via la fonction dédiée
-- -----------------------------------------------------------------------------
drop policy if exists "restaurants_lecture_restaurateur" on public.restaurants;
create policy "restaurants_lecture_restaurateur" on public.restaurants
  for select to authenticated
  using (id = public.etablissement_du_restaurateur());

drop policy if exists "restaurants_ecriture_restaurateur" on public.restaurants;
create policy "restaurants_ecriture_restaurateur" on public.restaurants
  for update to authenticated
  using (id = public.etablissement_du_restaurateur())
  with check (
    id = public.etablissement_du_restaurateur()
    -- Le niveau de vérification ne peut pas être modifié par le restaurateur :
    -- la comparaison porte explicitement sur la ligne contrôlée (restaurants.id),
    -- et non sur une sous-requête non corrélée.
    and niveau_verification = (
      select r.niveau_verification from public.restaurants r where r.id = restaurants.id
    )
  );

comment on policy "restaurants_ecriture_restaurateur" on public.restaurants is
  'Un restaurateur ne peut modifier QUE sa fiche, et jamais son niveau de vérification (contrôle explicite sur la ligne modifiée).';

-- -----------------------------------------------------------------------------
-- 3. Contrôle du cloisonnement laissé inchangé : les politiques de 0005 tirent
--    leur condition de la politique de `restaurants`, qui vient d'être corrigée.
--    On rejoue la création des politiques filles pour qu'elles soient réévaluées
--    avec les fonctions corrigées (aucune donnée touchée).
-- -----------------------------------------------------------------------------
do $$
declare
  table_fille text;
  filles text[] := array[
    'contacts', 'menus', 'plats', 'horaires', 'horaires_exceptionnels',
    'zones_livraison', 'etablissement_services', 'etablissement_categories',
    'etablissement_sources', 'etablissement_exploitation'
  ];
begin
  foreach table_fille in array filles loop
    execute format('drop policy if exists "%s_lecture_publique" on public.%I', table_fille, table_fille);
    execute format(
      'create policy "%s_lecture_publique" on public.%I for select to anon, authenticated '
      'using (exists (select 1 from public.restaurants r where r.id = %I.restaurant_id))',
      table_fille, table_fille, table_fille
    );
  end loop;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Vue d'aide à l'administration : qui peut accéder à quoi (diagnostic des rôles)
-- -----------------------------------------------------------------------------
create or replace view public.v_acces_comptes as
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
order by u.role, u.email;

comment on view public.v_acces_comptes is
  'Qui accède à quoi : rôle, activité et périmètre. Lisible uniquement par l''administration — la vue sert à vérifier qu''un restaurateur n''a bien que son établissement et qu''aucun compte inactif ne conserve d''accès.';

revoke all on public.v_acces_comptes from public, anon, authenticated;
