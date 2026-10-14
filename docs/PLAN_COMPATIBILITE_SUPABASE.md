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
