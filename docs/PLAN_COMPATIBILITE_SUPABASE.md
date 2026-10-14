# Plan de compatibilité — Supabase distant DEKK FOOD

Date de constat : 14 octobre 2026  
Projet : `bfuvbshocvpfeqfabwti` (Dekk Food, eu-west-2)  
Branche de travail : `arena/c3d3f8c4-dekk-food`

## Statut et périmètre

Ce document prépare la migration de compatibilité. **Aucune migration SQL n'est appliquée à Supabase** et aucune donnée n'est modifiée par ce constat. La PR #2 reste ouverte, non fusionnée ; `main` n'est pas modifiée.

## Constats vérifiés en lecture seule

- Le projet Supabase répond avec le statut `ACTIVE_HEALTHY`.
- Les tables présentes dans le schéma `public` sont `restaurants`, `restaurant_menus` et `restaurant_reviews`.
- Les comptes SQL de lignes donnent actuellement : `restaurants = 1`, `restaurant_menus = 6`, `restaurant_reviews = 0`. L'indication de nombre de lignes renvoyée par l'outil de liste des tables était différente ; les comptes SQL directs sont retenus ici.
- `restaurants.id`, `restaurant_menus.id`, `restaurant_menus.restaurant_id`, `restaurant_reviews.id` et `restaurant_reviews.restaurant_id` sont de type `integer` ; les identifiants sont liés à des séquences.
- `restaurants` contient notamment `name`, `slug`, `neighborhood` et des champs de contact/géolocalisation. La table distante ne correspond pas au schéma de référence décrit par `supabase/schema.sql` dans le dépôt.
- Les migrations 0001–0007 ont été écrites autour d'un modèle où `restaurants.id` est un UUID. Par exemple, 0002 déclare `menus.restaurant_id uuid references public.restaurants(id)`; 0003 déclare `utilisateurs_admin.restaurant_id uuid references public.restaurants(id)`. Ces contraintes ne peuvent pas être appliquées directement à la table distante dont `restaurants.id` est un entier.
- Les tables distantes ont RLS activée, mais aucune policy RLS n'est actuellement définie. Les privilèges SQL accordés à `anon` et `authenticated` sont larges, mais RLS sans policy bloque normalement leurs accès aux lignes via l'API. Ne pas traiter ce constat en ajoutant une policy permissive.
- L'advisor sécurité signale 3 tables RLS sans policy. L'advisor performance signale l'absence d'index couvrant les clés étrangères `restaurant_menus.restaurant_id` et `restaurant_reviews.restaurant_id`.
- Aucune migration n'apparaît dans l'historique renvoyé par l'outil Supabase. Cela ne prouve pas à lui seul qu'aucun SQL n'a jamais été exécuté : l'historique de migrations du dépôt et celui du projet distant ne sont pas encore réconciliés.

## Décision technique requise avant d'écrire le SQL de migration

Ne pas exécuter les migrations 0001–0007 en bloc sur le projet distant. Il existe deux modèles incompatibles : le modèle distant historique à clés entières et le modèle du dépôt à identifiants UUID.

La voie prudente à étudier est de **conserver les clés entières et les lignes historiques**, puis d'introduire un identifiant UUID stable distinct pour les nouvelles relations du catalogue, en adaptant de façon cohérente les migrations et les vues qui font référence à `restaurants.id`. Avant de retenir cette option, il faut vérifier toutes les références aux identifiants dans les migrations, les seeds, les vues, les fonctions et le code Flutter. Une conversion directe de la clé primaire existante vers UUID n'est pas autorisée dans ce plan.

## Étapes de compatibilité — sans toucher à la production

1. Cartographier toutes les références à `restaurants.id` et aux tables historiques `restaurant_menus` / `restaurant_reviews` dans les sept migrations, les seeds et le code client.
2. Définir une table de correspondance explicite entre chaque ligne historique et le nouvel identifiant de catalogue ; aucune correspondance ne doit être devinée à partir du nom.
3. Concevoir un script non destructif et réexécutable : pré-vérifications bloquantes, création des structures manquantes, correspondances stables, import idempotent des données existantes, contrôles de clés étrangères et bilan avant/après.
4. Définir les policies RLS selon les parcours réels : lecture publique uniquement des fiches explicitement publiées ; écritures réservées aux rôles appropriés ; restaurateur limité à sa propre fiche ; vues et fonctions internes réservées à l'administration. Aucun `USING (true)` générique ni exposition de `service_role` au client.
5. Ajouter les index de clés étrangères manquants si le modèle final les requiert.
6. Tester le SQL sur une base PostgreSQL jetable initialisée à partir du schéma distant et de ses données de test représentatives. Vérifier le scénario de réexécution, les comptes, les clés étrangères, les droits des rôles et les chemins public/admin/restaurateur.
7. Seulement après réussite des tests, faire relire le diff et le plan de retour arrière. Une éventuelle application en production demandera une décision explicite distincte.

## Critères d'acceptation

- Aucune suppression ni conversion destructive des identifiants historiques.
- Les 1 restaurant et 6 lignes de menu sont conservés et reliés correctement après migration de test.
- Aucune ligne enfant orpheline ; aucun doublon créé lors d'une seconde exécution.
- Les accès anonymes, authentifiés, administrateur et restaurateur sont testés avec leurs droits attendus.
- Les trois alertes de sécurité et les deux alertes d'index sont réévaluées après le modèle final.
- La production reste inchangée pendant toute la préparation et les tests.

## Garde-fou ajouté

Le fichier `supabase/diagnostics/preflight_migrations_0001_0007.sql` est un contrôle structurel non destructif. Il bloque volontairement si `restaurants.id` n'est pas de type UUID ou si les colonnes héritées attendues sont absentes. Il ne corrige pas le schéma et ne remplace pas un test de migration. Il n'a pas été exécuté sur la production.

## État de ce document

Plan préparatoire uniquement. Aucun SQL de migration de compatibilité n'est encore prêt à appliquer. Le précontrôle ajouté est un garde-fou, pas la migration. Le SQL de compatibilité ne doit être écrit qu'après la cartographie complète des dépendances et le choix du modèle d'identifiants.

## Cartographie technique vérifiée — dépendances d'identifiants

Cette section complète le constat initial après lecture des sept migrations et du code Flutter sur la branche de travail. Elle ne constitue pas une autorisation d'appliquer du SQL.

### 1. Références dans les migrations

- **Migration 0001 — référentiel/catalogue :** crée plusieurs relations enfant avec `restaurant_id uuid references public.restaurants(id)`, notamment les catégories d'établissement, l'exploitation/gestionnaires, les contacts, les sources et les vérifications. Les index et triggers s'appuient également sur les colonnes ajoutées à `restaurants`.
- **Migration 0002 — menus et services :** déclare de nombreuses colonnes `restaurant_id` de type UUID dans `menus`, `plats`, `images`, `horaires`, les zones de livraison, les avis et les tables de liaison/détection de doublons. Certaines contraintes d'index utilisent explicitement un UUID sentinelle.
- **Migration 0003 — rôles et vues :** `utilisateurs_admin.restaurant_id` est un UUID et les politiques RLS comparent directement `restaurants.id` à cette clé. Plusieurs vues joignent les tables filles par cette relation.
- **Migrations 0004–0007 :** les vues de publication, les politiques de cloisonnement, la fonction de périmètre restaurateur, le déclencheur de modification et les vues d'administration continuent d'utiliser `restaurants.id` comme identifiant parent. Le changement de clé doit donc être traité comme une modification transversale, pas comme une conversion isolée de colonne.
- **Seed :** `supabase/seed/00_referentiel.sql` charge le référentiel géographique (ses identifiants numériques sont distincts des identifiants de restaurant). `supabase/seed/10_etablissements.sql` est un fichier généré volumineux ; il doit être analysé par son générateur et ses contrôles de reproductibilité avant d'être adapté. Ne pas éditer manuellement ce fichier généré.
- **Schéma de référence :** `supabase/schema.sql` crée un premier modèle minimal UUID avec `restaurants` et `menu_items`. Ce fichier ne décrit pas le schéma historique actuellement observé sur le projet distant.

### 2. Références dans Flutter

Deux parcours coexistent actuellement :

1. **Catalogue national principal :** `lib/data/catalogue_repository.dart` charge `assets/data/catalogue.json`, généré à partir des données de `data/seed`. Les identifiants des établissements sont manipulés comme des chaînes dans `lib/models/catalogue.dart` et servent notamment aux favoris et aux contributions locales. Ce parcours embarqué ne nécessite pas de conversion de clé SQL pour afficher le catalogue hors ligne.
2. **Service Supabase historique :** `lib/services/supabase_service.dart` interroge directement `restaurants` en filtrant `is_active`, puis `menu_items` avec `restaurant_id`. `lib/models/restaurant.dart` déclare les identifiants comme `String` et lit directement les valeurs JSON. Or le schéma distant observé possède des identifiants entiers, tandis que ce modèle attend une chaîne : ce chemin mérite un test d'intégration explicite avant d'être considéré compatible. Les tables `restaurant_menus` et `restaurant_reviews` du projet distant ne sont pas les tables `menus`, `plats` et `avis` du nouveau catalogue.
3. **Contributions :** les avis et demandes du catalogue utilisent un identifiant d'établissement textuel dans le stockage local. Il ne faut pas supposer que cette chaîne est un UUID de base ni la convertir automatiquement en clé numérique sans une table de correspondance explicite.

### 3. Décision de conception — aucune conversion automatique

La cartographie confirme qu'une simple conversion de `restaurants.id` de integer en UUID casserait des clés étrangères historiques et ne suffirait pas à rendre cohérentes les migrations. Deux options restent à comparer dans un environnement jetable :

- **Option A — préserver la clé entière historique :** conserver les identifiants entiers des trois tables historiques, puis adapter le nouveau catalogue avec une clé UUID distincte et stable, ainsi qu'une correspondance explicite entre l'identifiant historique et l'identifiant de catalogue. Toutes les relations, vues, fonctions, policies et tests concernés doivent utiliser la bonne clé de manière cohérente.
- **Option B — modèle de catalogue séparé :** garder les trois tables historiques intactes et créer un espace de catalogue UUID distinct, puis migrer les données de façon idempotente avec une table de correspondance vérifiable. Cette option isole davantage l'ancien service Flutter, mais exige de décider si et comment les fiches historiques sont réconciliées avec les fiches du catalogue national.

Aucune des deux options ne doit être choisie seulement sur la base du nom d'un établissement. Le rapprochement des lignes doit utiliser une clé historique conservée, ou être validé explicitement lorsqu'aucune clé stable n'existe.

### 4. Prochaine vérification obligatoire

Avant d'écrire la migration candidate :
- inspecter les colonnes et contraintes complètes des trois tables distantes en lecture seule, y compris les séquences, triggers, politiques, privilèges et vues dépendantes ;
- analyser le générateur du seed pour savoir comment les IDs de catalogue sont produits et garantir la reproductibilité ;
- décider quel parcours Flutter est la source de vérité et tester le service Supabase historique avec les types JSON réellement renvoyés ;
- créer une fixture locale représentant exactement le schéma distant (integer + six menus), puis tester les deux options sur PostgreSQL jetable, avec exécution répétée, comptes avant/après, intégrité référentielle et tests RLS.

**Aucune migration de compatibilité n'est encore prête à exécuter.** La seule migration sûre à ce stade est celle qui sera démontrée par ces tests sur une copie jetable, puis revue avant toute autorisation séparée de production.
