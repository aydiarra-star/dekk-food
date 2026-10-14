# Plan d'intégration du catalogue isolé — sans migration de production

Date : 14 octobre 2026. Statut : plan de travail, aucune migration exécutable.

## État confirmé

- Le prototype `tools/tests/test_catalogue_isolation.py` réussit dans la CI sur PostgreSQL jetable.
- Le schéma historique réel observé sur Supabase utilise des identifiants entiers dans `public.restaurants`, `public.restaurant_menus` et `public.restaurant_reviews`.
- Le catalogue SQL actuel n'est pas isolé : le générateur `tools/catalogue/generation.py` émet des requêtes qualifiées `public.*` et dépend du référentiel, des sources et des tables relationnelles du même espace.
- Les migrations 0001–0007 sont conçues pour étendre `public.restaurants`, pas pour créer à elles seules un catalogue UUID autonome.

## Pourquoi un simple renommage de table ne suffit pas

Le générateur écrit dans les familles suivantes, à vérifier systématiquement lors du refactor :

- identité et géographie : `restaurants`, `regions`, `departements`, `communes`, `quartiers`, `types_etablissement` ;
- nomenclature et provenance : `categories_culinaires`, `services`, `allergenes`, `regimes_alimentaires`, `sources` ;
- relations d'établissement : `etablissement_categories`, `contacts`, `horaires`, `etablissement_services`, `zones_livraison`, `images` ;
- menus et plats : `menus`, `plats`, `plat_allergenes`, `plat_regimes` ;
- exploitation et traçabilité : `entreprises`, `etablissement_exploitation`, `etablissement_sources`.

Les migrations ajoutent également fonctions, triggers, vues, contraintes, politiques RLS et grants. Les déplacer de `public` vers un autre schéma exige de revoir leurs références croisées, leurs droits et les appels applicatifs.

## Ordre de travail recommandé

1. **Cartographier les consommateurs** : générateur, seed SQL généré, migrations, vues/fonctions, services Flutter, tests et éventuels appels PostgREST.
2. **Décider du modèle** : conserver sans changement les tables historiques ; isoler le nouveau catalogue et toutes ses tables dépendantes dans un schéma dédié, ou choisir explicitement une autre stratégie après comparaison. Ne pas mélanger des identifiants integer et UUID dans une même relation.
3. **Créer le schéma cible sur PostgreSQL jetable** : toutes les tables, clés, contraintes, fonctions et index nécessaires ; aucune dépendance implicite au schéma `public`.
4. **Adapter le générateur avec une cible explicite** : aucun remplacement textuel global de `public` ; les noms de schéma doivent être contrôlés/validés, et la cible par défaut ne doit pas permettre une écriture accidentelle en production.
5. **Générer le seed et tester** : première insertion, second passage, mise à jour par slug, conservation des données non publiées, absence de doublons dans les relations.
6. **Tester les accès** : rôle anonyme, utilisateur authentifié, restaurateur et administrateur ; lecture des seules fiches publiées ; isolation des données non publiées ; refus des écritures non autorisées ; vues/fonctions avec droits explicites.
7. **Adapter Flutter sans supprimer le chemin catalogue embarqué/hors ligne** : séparer le modèle historique du modèle catalogue ; tests de désérialisation integer/UUID et de noms de colonnes.
8. **Rejouer toute la CI** puis comparer les résultats et les volumes attendus. Refaire un inventaire Supabase en lecture seule juste avant toute proposition de migration.

## Critères d'acceptation avant fusion

- Tous les tests CI passent sur la dernière SHA.
- Le seed complet généré cible uniquement le schéma choisi et est idempotent.
- Les tests prouvent que les identifiants, lignes, avis et menus historiques ne changent pas.
- Les tests RLS/grants couvrent les rôles et chemins de lecture/écriture pertinents.
- Flutter et le catalogue hors ligne continuent à fonctionner.
- Une revue humaine approuve une migration distincte, avec sauvegarde et plan de retour arrière.

## Interdictions maintenues

Aucune migration, écriture SQL, modification de RLS/grants, seed ou changement de données sur Supabase de production pendant cette phase. Ne pas fusionner et ne pas déployer avant les critères ci-dessus.
