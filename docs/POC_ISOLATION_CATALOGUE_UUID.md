# Preuve de concept — coexistence du schéma historique et du catalogue UUID

Date : 14 octobre 2026.

## Objectif

Démontrer sur PostgreSQL jetable que le catalogue DEKK FOOD peut être isolé sans convertir ni remplacer les tables historiques actuellement observées sur Supabase : `public.restaurants`, `public.restaurant_menus` et `public.restaurant_reviews`.

## Prototype automatisé

Le test `tools/tests/test_catalogue_isolation.py` crée deux espaces séparés :

- **Historique** : tables dans `public`, clés primaires et étrangères entières.
- **Nouveau catalogue** : table `catalogue.restaurants`, clé UUID, contrainte unique sur `slug`, et champ de publication.

Il vérifie :
1. les deux modèles coexistent dans une même base PostgreSQL ;
2. un seed avec `ON CONFLICT (slug) DO UPDATE` peut être rejoué deux fois sans doublon ;
3. les lignes et relations historiques restent inchangées ;
4. le rôle `anon` ne lit que les fiches publiées dans le nouveau catalogue grâce à RLS ;
5. le rôle `anon` ne dispose pas d'accès aux tables historiques.

## Limites explicites

Ce prototype est une **preuve de concept minimale**, pas un portage des migrations 0001–0007 ni du générateur actuel. Le générateur `tools/catalogue/generation.py` écrit encore dans `public.restaurants` et dépend de référentiels comme `public.sources`, `public.regions`, `public.departements`, `public.communes` et `public.quartiers`. Il faudra adapter en cohérence le générateur, toutes les migrations, les seeds et les consommateurs SQL/Flutter avant de prétendre que le catalogue complet est isolé.

La politique RLS testée ici illustre un accès de lecture public minimal. Les rôles d'administration/restaurateur, les écritures authentifiées, les grants de production, les vues et les fonctions doivent faire l'objet de tests dédiés avant toute proposition de migration réelle.

## Sécurité et statut

- Le test n'utilise qu'un PostgreSQL temporaire local au runner CI.
- Aucune requête d'écriture n'a été envoyée au projet Supabase distant.
- Ce document ne constitue ni une autorisation ni un script de migration de production.
- La PR doit rester non fusionnée jusqu'à l'adaptation et la validation de l'ensemble du pipeline.
