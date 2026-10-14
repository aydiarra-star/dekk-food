# Contrat de schéma du catalogue isolé — DEKK FOOD

Date : 14 octobre 2026  
Statut : inventaire technique préalable ; **ce document ne constitue pas une migration exécutable**.

## 1. But et frontière

Le nouveau catalogue doit vivre dans le schéma PostgreSQL `catalogue`, séparé du schéma historique `public`. Le schéma historique observé contient notamment `public.restaurants.id` et `public.restaurant_menus.restaurant_id` de type integer. Le modèle catalogue des migrations actuelles est construit autour d'identifiants UUID et de nombreuses tables liées.

**Interdiction de compatibilité implicite :** une clé entière de l'ancien modèle ne doit jamais être castée en UUID ni réutilisée comme identifiant du nouveau catalogue. Aucune FK du nouveau schéma ne doit pointer vers les tables historiques. Les migrations `0001–0007` restent inchangées et ne sont pas réutilisables telles quelles pour `catalogue`.

## 2. Dépendances du seed généré

Le générateur `tools/catalogue/generation.py` construit des instructions SQL explicitement qualifiées en `public.*`. Le paramètre `--schema-cible catalogue` ne fait que qualifier les références relationnelles du seed ; il ne crée ni les tables, ni les contraintes, ni les fonctions, ni les policies, ni les privilèges nécessaires.

Les familles d'objets directement référencées par le générateur doivent être prises en charge et vérifiées dans le schéma cible :

- **Établissements et géographie** : `restaurants`, `regions`, `departements`, `communes`, `quartiers`.
- **Référentiels** : `sources`, `types_etablissement`, `categories_culinaires`, `services`, `allergenes`, `regimes_alimentaires`.
- **Relations établissement** : `contacts`, `horaires`, `etablissement_categories`, `etablissement_services`, `zones_livraison`, `etablissement_sources`, `entreprises`, `etablissement_exploitation`.
- **Menus et médias** : `menus`, `plats`, `images`, `plat_allergenes`, `plat_regimes`.

Cette liste est la surface visible dans le générateur, pas une preuve que tous les objets sont inventoriés : les FK, triggers, fonctions, index, vues, policies et objets dynamiques des migrations doivent être cartographiés séparément avant de figer le contrat.

## 3. Contrat minimal pour la migration dédiée

La série dédiée doit :

1. Créer explicitement le schéma `catalogue` et qualifier chaque objet de façon non ambiguë.
2. Définir les tables, colonnes, types, valeurs par défaut, contraintes CHECK, clés uniques et FK réellement utilisées par le seed.
3. Maintenir des clés UUID cohérentes à l'intérieur du catalogue ; toute référence de table enfant doit cibler une table du schéma `catalogue`.
4. Préserver les règles de provenance : les informations confirmées doivent conserver une source traçable ; aucune image générique ne doit être présentée comme une photo authentique ; une fiche non publiable doit rester non publiée avec un motif.
5. Garantir l'idempotence du seed sur deux exécutions successives, sans doublons ni perte de données.
6. Définir la publication et les autorisations par défaut comme privées ; accorder les droits nécessaires table par table, puis activer et tester RLS. Un `GRANT` ne remplace pas une policy RLS et inversement.
7. Définir les fonctions nécessaires dans le bon schéma, avec toutes les références qualifiées et un `search_path` fixé. Ne pas recopier automatiquement les fonctions `SECURITY DEFINER` historiques.
8. Laisser les tables historiques, colonnes, contraintes, privilèges et données de `public` strictement inchangés.

## 4. Contrat de vérification PostgreSQL jetable

Le test d'intégration dédié devra démarrer avec des tables historiques `public` représentatives et des lignes témoins, puis :

- prendre une photographie de la structure et des données historiques ;
- appliquer uniquement les migrations dédiées au catalogue ;
- exécuter le seed catalogue deux fois ;
- vérifier les comptages, les clés uniques, les FK, les contraintes et la parité avec les fiches du catalogue source ;
- vérifier dans les catalogues système qu'aucun objet catalogue n'a été créé dans `public` ;
- rechercher toutes les FK de `catalogue` vers `public` et exiger zéro résultat ;
- tester les privilèges effectifs et la RLS avec les rôles `anon`, `authenticated` et le rôle administratif de test ;
- prouver que `anon` ne peut lire ni fiches non publiées, ni données historiques privées, ni vues internes ;
- comparer la photographie historique après migration et exiger une égalité exacte ;
- terminer en erreur au moindre contrôle non exécuté ou résultat inattendu. Un test sauté parce qu'une dépendance manque ne doit jamais compter comme un succès.

## 5. Séparation des modèles applicatifs

Le service Flutter actuellement documenté utilise le modèle historique : `restaurants` avec identifiants numériques et `restaurant_menus`. Le catalogue isolé UUID ne doit pas devenir la source de ce service par simple changement de schéma. Il faut une décision explicite de source, un adaptateur/modèle dédié et des tests de désérialisation séparés, tout en préservant le fonctionnement existant.

## 6. État et décision

- Les tests actuels valident les migrations historiques dans `public` sur PostgreSQL jetable.
- Le test de coexistence actuel est un POC limité ; il ne valide pas les migrations complètes.
- Le qualificateur de seed ne transforme pas le SQL dynamique des migrations et ne suffit pas à isoler les objets.
- **Aucune migration dédiée complète n'est déclarée prête à ce stade.**

Étape suivante obligatoire : traduire cet inventaire en DDL dédié, vérifier le contrat exact de chaque colonne contre le générateur, puis créer un test d'intégration PostgreSQL complet. Tant que ces tests ne sont pas verts, ne pas exécuter ce chemin sur Supabase réel.

## Garde-fous

Aucune connexion ni écriture Supabase de production. Aucun changement de données canoniques. Aucune migration historique modifiée pour simuler l'isolation. Aucune fusion de PR ni aucun déploiement sans autorisation explicite.
