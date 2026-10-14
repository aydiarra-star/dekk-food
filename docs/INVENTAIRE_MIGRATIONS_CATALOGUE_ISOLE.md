# Inventaire statique des migrations 0001–0007 — catalogue isolé

Date de l'inventaire : 14 octobre 2026. Branche analysée : `arena/c3d3f8c4-dekk-food`, HEAD `c88b20ac60da6bb8b573b1bbc1a9584ca58c9570`.

## Décision immédiate

**Ne pas appliquer les migrations 0001–0007 sur Supabase production.** La base existante utilise des identifiants entiers dans `public.restaurants`, `public.restaurant_menus` et `public.restaurant_reviews`, alors que les migrations historiques attendent un modèle catalogue avec UUID. Le précontrôle actuel doit continuer à bloquer cette voie.

Cet inventaire est statique : il repère les déclarations et les dépendances explicites, mais ne remplace ni l'analyse complète de chaque corps SQL ni un test d'intégration sur PostgreSQL jetable. Les comptes sont des décomptes lexicaux et peuvent compter plusieurs fois un objet modifié ou redéfini dans des migrations successives.

## Carte des objets par migration

| Migration | Objets principaux déclarés | Dépendances / points sensibles |
| --- | --- | --- |
| `0001_referentiel_et_catalogue.sql` | 17 tables, 6 fonctions, 2 triggers, environ 25 index ; extensions `pg_trgm` et `unaccent` | Référentiels géographiques, établissements/restaurants, entreprises et gestionnaires, sources et vérifications. Définit des fonctions utilitaires et des index de recherche. |
| `0002_menus_images_services.sql` | 19 tables, 1 fonction, 4 triggers, environ 18 index | Menus, sections, plats, allergènes/régimes, promotions, images, horaires, avis, signalements, imports et journal de modifications. Plusieurs objets dépendent du modèle restaurant défini en 0001. |
| `0003_securite_vues_admin.sql` | 1 table, 6 fonctions, 8 vues, 12 politiques RLS, 4 instructions GRANT repérées | Identité/roles administrateur, vues de couverture et de qualité, vues publiques et vues de modération. Dépend du schéma catalogue et des rôles Supabase. |
| `0004_publication_validation_provenance.sql` | 3 fonctions, 2 vues, 1 trigger, 2 index ; instructions REVOKE repérées | Statuts de publication, provenance et validation. Modifie les tables existantes ; ne constitue pas un module autonome. |
| `0005_cloisonnement_public.sql` | 1 vue, 2 index, 11 politiques RLS ; instructions REVOKE repérées | Contrôle du cloisonnement entre données publiques, entreprise et gestionnaire. À revalider après toute séparation de schémas. |
| `0006_acces_admin_restaurateur.sql` | 3 fonctions, 1 vue, 3 politiques RLS ; instructions REVOKE repérées | Rôles administrateur/restaurateur et rattachement d'un restaurateur à un établissement. Dépend des identifiants et relations du modèle catalogue. |
| `0007_securite_vues_et_fonctions.sql` | 5 fonctions, 12 vues, 1 trigger, politiques, environ 20 GRANT et 15 REVOKE repérés | Durcissement final des vues et fonctions, contrôle de modification, permissions et accès aux vues. Réécrit plusieurs objets déjà définis dans les migrations précédentes. |

## Familles de tables repérées

### Référentiel et établissement — migration 0001
`regions`, `departements`, `communes`, `quartiers`, `types_etablissement`, `categories_culinaires`, `services`, `allergenes`, `regimes_alimentaires`, `sources`, `entreprises`, `gestionnaires`, `etablissement_categories`, `etablissement_exploitation`, `contacts`, `etablissement_sources`, `verifications`.

La migration contient également des références à `public.restaurants` et à d'autres objets du catalogue. Il faut vérifier les noms exacts, types, clés, contraintes et index dans le fichier SQL complet avant de proposer un déplacement.

### Menus et exploitation — migration 0002
`menus`, `menu_sections`, `plats`, `plat_allergenes`, `plat_regimes`, `plat_promotions`, `images`, `horaires`, `horaires_exceptionnels`, `etablissement_services`, `zones_livraison`, `avis`, `signalements`, `demandes_correction`, `revendications`, `import_lots`, `import_lignes`, `doublons_suspects`, `journal_modifications`.

### Administration et sécurité — migrations 0003 à 0007
Les vues et fonctions réutilisent les tables des migrations précédentes et sont parfois redéfinies dans les migrations ultérieures. Il faut donc préserver l'ordre d'application et vérifier les signatures, dépendances et privilèges effectifs ; créer uniquement les tables dans un nouveau schéma ne suffit pas.

## Pourquoi le remplacement textuel de `public.` ne suffit pas

Le paramètre `schema_cible` du générateur est une première brique, pas un mécanisme d'isolation complet. Avant de pouvoir générer ou exécuter un seed vers `catalogue`, il reste à traiter et tester :

1. **Création du schéma cible** et définition des propriétaires/permissions, sans toucher aux tables historiques.
2. **Toutes les migrations** : tables, contraintes, clés étrangères, index, triggers, fonctions, vues et vues de sécurité doivent viser les bons objets et être créés dans un ordre cohérent.
3. **Références SQL non qualifiées**, signatures de fonctions, types, opérateurs, `search_path`, extensions et fonctions d'extension. Un remplacement de texte ne résout pas à lui seul ces dépendances.
4. **Sécurité** : politiques RLS, GRANT/REVOKE, droits sur le schéma, les tables, séquences, fonctions et vues ; comportement réel pour `anon`, `authenticated` et `service_role`.
5. **Générateur et seed** : le SQL produit doit viser le même schéma que les tables, référentiels et fonctions attendus. Le comportement par défaut `public` doit rester inchangé.
6. **Consommateurs Flutter/API** : chaque lecture et écriture doit être dirigée vers le modèle compatible et ne doit pas exposer par erreur les anciennes tables.
7. **Compatibilité et retour arrière** : démontrer par tests que les données historiques, leurs IDs entiers et leurs relations restent intactes.

## Prochaine tranche sûre

1. Ajouter un banc de test PostgreSQL jetable qui applique les migrations adaptées au schéma `catalogue`, sans accès à la base de production.
2. Comparer automatiquement les objets attendus et créés : tables, colonnes/types, clés/contraintes, index, fonctions, vues, triggers, RLS/policies et privilèges.
3. Exécuter le seed deux fois pour vérifier l'idempotence, puis vérifier que les tables historiques `public.*` restent intactes.
4. Tester les permissions en tant que `anon`, `authenticated` et rôle de service, en prouvant que seules les fiches publiées sont accessibles au public et que les tables historiques ne sont pas exposées.
5. N'envisager une migration de production qu'après revue explicite et autorisation de l'utilisateur.

## Vérification CI

Le run CI du HEAD inventorié est terminé avec succès : [run 38564928025](https://github.com/aydiarra-star/dekk-food/actions/runs/38564928025). Cela valide la suite actuellement automatisée, mais **ne signifie pas que l'isolation complète des migrations est déjà implémentée ou validée**.
