-- =============================================================================
-- DEKK FOOD / DAKA FOOD — Migration 0004
-- Publication explicite, provenance traçable et validation avant publication
-- =============================================================================
-- Objectifs :
--   1. une seule règle de publication, appliquée par le pipeline ET par la base ;
--   2. une fiche non publiée est CONSERVÉE et porte son motif (aucune suppression) ;
--   3. une fiche conforme au schéma n'est pas une fiche vérifiée : la validation
--      est un acte humain tracé (qui, quand, sur quelle preuve) ;
--   4. une revendication de restaurateur ne vaut jamais vérification ;
--   5. l'autorisation d'image devient exigible pour une photo présentée comme
--      authentique.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Colonnes de traçabilité sur les établissements
-- -----------------------------------------------------------------------------
alter table public.restaurants
  add column if not exists motif_non_publication  text,
  add column if not exists statut_validation      text not null default 'non_validee',
  add column if not exists validation_par         uuid,
  add column if not exists validation_le          timestamptz;

comment on column public.restaurants.motif_non_publication is
  'Motif lisible expliquant pourquoi la fiche n''est pas publiée. Obligatoire dès que est_publication_visible = false : une fiche écartée est conservée et expliquée, jamais supprimée.';
comment on column public.restaurants.statut_validation is
  'État du contrôle humain : non_validee (valeur par défaut), en_cours, validee, rejetee. Une fiche publiée peut rester non_validee : « publiée » ne veut pas dire « vérifiée ».';
comment on column public.restaurants.validation_par is
  'Identifiant de la personne (rôle admin ou editeur) qui a validé la fiche. Obligatoire pour statut_validation = « validee ».';
comment on column public.restaurants.validation_le is
  'Horodatage de la validation humaine.';

-- Reprise NON destructive : une fiche déjà non publiée doit porter un motif.
-- Le texte dit explicitement que ce motif est historique et reste à confirmer.
update public.restaurants
   set motif_non_publication = 'motif non renseigné avant la version 4 du schéma — à confirmer'
 where est_publication_visible = false
   and coalesce(btrim(motif_non_publication), '') = '';

-- -----------------------------------------------------------------------------
-- 2. Contraintes : la règle de publication devient impossible à contourner
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'restaurants_statut_validation_check') then
    alter table public.restaurants add constraint restaurants_statut_validation_check
      check (statut_validation in ('non_validee', 'en_cours', 'validee', 'rejetee'));
  end if;

  -- « validee » exige une personne identifiée et une date : pas de validation anonyme.
  if not exists (select 1 from pg_constraint where conname = 'restaurants_validation_coherence_check') then
    alter table public.restaurants add constraint restaurants_validation_coherence_check
      check (statut_validation <> 'validee'
             or (validation_par is not null and validation_le is not null));
  end if;

  -- Le badge « vérifié » ne s'obtient que par une validation tracée.
  if not exists (select 1 from pg_constraint where conname = 'restaurants_verifie_exige_validation_check') then
    alter table public.restaurants add constraint restaurants_verifie_exige_validation_check
      check (niveau_verification <> 'verifie'
             or (statut_validation = 'validee' and validation_par is not null));
  end if;

  -- Une fiche dont l'information est indisponible ne se publie pas.
  if not exists (select 1 from pg_constraint where conname = 'restaurants_information_indisponible_check') then
    alter table public.restaurants add constraint restaurants_information_indisponible_check
      check (niveau_verification <> 'information_indisponible'
             or est_publication_visible = false);
  end if;

  -- Toute fiche non publiée porte un motif : rien n'est écarté en silence.
  if not exists (select 1 from pg_constraint where conname = 'restaurants_motif_non_publication_check') then
    alter table public.restaurants add constraint restaurants_motif_non_publication_check
      check (est_publication_visible
             or coalesce(btrim(motif_non_publication), '') <> '');
  end if;
end;
$$;

create index if not exists idx_restaurants_validation on public.restaurants(statut_validation);
create index if not exists idx_restaurants_non_publiees
  on public.restaurants(est_publication_visible) where not est_publication_visible;

-- -----------------------------------------------------------------------------
-- 3. Images : une photo authentique doit avoir des droits documentés
-- -----------------------------------------------------------------------------
alter table public.images
  add column if not exists autorisation_reference   text,
  add column if not exists autorisation_obtenue_le  date;

comment on column public.images.autorisation_reference is
  'Référence de l''autorisation (courriel du restaurateur, contrat, licence) : sans elle, l''image n''est pas présentée comme authentique.';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'images_authentique_droits_check') then
    alter table public.images add constraint images_authentique_droits_check
      check (correspondance_verifiee = false
             or auteur is not null
             or licence is not null
             or coalesce(btrim(autorisation_usage), '') <> ''
             or coalesce(btrim(autorisation_reference), '') <> '');
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Revendications : jamais de badge automatique
-- -----------------------------------------------------------------------------
create or replace function public.controler_revendication()
returns trigger
language plpgsql
as $$
begin
  if new.statut = 'verifiee' then
    if new.verifie_par is null or new.verifie_le is null then
      raise exception 'Revendication refusée : le statut « verifiee » exige une vérification HUMAINE identifiée (verifie_par et verifie_le). Une revendication ne vaut jamais vérification de la fiche.';
    end if;
  end if;
  if new.statut = 'rejetee' and coalesce(btrim(new.commentaire), '') = '' then
    raise exception 'Revendication refusée : un rejet doit être motivé (commentaire obligatoire).';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_revendications_controle on public.revendications;
create trigger trg_revendications_controle
  before insert or update on public.revendications
  for each row execute function public.controler_revendication();

comment on function public.controler_revendication() is
  'Empêche qu''une revendication devienne « vérifiée » sans intervention humaine identifiée, et un rejet non motivé.';

-- -----------------------------------------------------------------------------
-- 5. Actes de contrôle : validation et dévalidation tracées
-- -----------------------------------------------------------------------------
create or replace function public.valider_fiche_par_controle(
  p_restaurant  uuid,
  p_niveau      text,
  p_preuves     text,
  p_commentaire text default null
)
returns text
language plpgsql
as $$
declare
  v_par   uuid := public.utilisateur_courant();
  v_avant text;
begin
  if not public.est_administrateur() then
    raise exception 'Validation réservée à l''administration (rôles admin ou editeur). Utilisateur courant : %.',
      coalesce(v_par::text, 'non identifié');
  end if;
  if p_niveau not in ('partiellement_verifie', 'verifie') then
    raise exception 'Niveau de validation invalide : « % » (attendu : partiellement_verifie ou verifie).', p_niveau;
  end if;
  if coalesce(btrim(p_preuves), '') = '' then
    raise exception 'Aucune preuve fournie : indiquez la référence de l''appel, du document ou de la source qui justifie la validation.';
  end if;

  select niveau_verification into v_avant from public.restaurants where id = p_restaurant;
  if not found then
    raise exception 'Établissement introuvable : %', p_restaurant;
  end if;

  update public.restaurants
     set niveau_verification     = p_niveau,
         statut_validation       = 'validee',
         validation_par          = v_par,
         validation_le           = now(),
         derniere_verification_le = current_date,
         commentaire_verification = concat_ws(' | ',
             nullif(btrim(coalesce(commentaire_verification, '')), ''),
             format('validation du %s (%s) : %s', current_date, p_niveau, btrim(p_preuves)),
             nullif(btrim(coalesce(p_commentaire, '')), '')),
         updated_at              = now()
   where id = p_restaurant;

  return format('Fiche %s : %s validé le %s par %s — preuve : %s',
                p_restaurant, p_niveau, current_date, v_par, btrim(p_preuves));
end;
$$;

create or replace function public.devalider_fiche(
  p_restaurant uuid,
  p_motif      text
)
returns text
language plpgsql
as $$
declare
  v_par uuid := public.utilisateur_courant();
begin
  if not public.est_administrateur() then
    raise exception 'Dévalidation réservée à l''administration (rôles admin ou editeur).';
  end if;
  if coalesce(btrim(p_motif), '') = '' then
    raise exception 'Une dévalidation doit être motivée (fermeture à vérifier, erreur signalée, demande de retrait…).';
  end if;

  update public.restaurants
     set statut_validation = 'non_validee',
         validation_par    = null,
         validation_le     = null,
         niveau_verification = case
             when niveau_verification = 'information_indisponible' then niveau_verification
             else 'a_confirmer'
         end,
         commentaire_verification = concat_ws(' | ',
             nullif(btrim(coalesce(commentaire_verification, '')), ''),
             format('dévalidation du %s : %s', current_date, btrim(p_motif))),
         updated_at = now()
   where id = p_restaurant;

  if not found then
    raise exception 'Établissement introuvable : %', p_restaurant;
  end if;

  return format('Fiche %s dévalidée le %s par %s — motif : %s', p_restaurant, current_date, v_par, btrim(p_motif));
end;
$$;

comment on function public.valider_fiche_par_controle(uuid, text, text, text) is
  'Seul chemin autorisé pour attribuer un niveau de vérification : exige un administrateur identifié et une preuve, et enregistre qui, quand et pourquoi.';
comment on function public.devalider_fiche(uuid, text) is
  'Retire un badge de vérification de façon tracée (fiche fermée, erreur signalée, demande de retrait).';

-- -----------------------------------------------------------------------------
-- 6. Vues d'administration : publication et file de validation
-- -----------------------------------------------------------------------------
create or replace view public.v_publication_catalogue as
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
order by e.est_publication_visible, e.name;

comment on view public.v_publication_catalogue is
  'État de publication de chaque fiche. Une fiche non publiée apparaît ici avec son motif : la divergence entre la base et le catalogue embarqué devient mesurable (comparer les deux compteurs).';

create or replace view public.v_fiches_a_valider as
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
order by contact_confirme desc, contacts desc, e.name;

comment on view public.v_fiches_a_valider is
  'File d''enrichissement et de validation : les fiches joignables (contact connu) d''abord, car ce sont celles qu''un appel ou un message peut vérifier directement.';

revoke all on public.v_publication_catalogue from public, anon, authenticated;
revoke all on public.v_fiches_a_valider from public, anon, authenticated;

revoke all on function public.valider_fiche_par_controle(uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.devalider_fiche(uuid, text) from public, anon, authenticated;
