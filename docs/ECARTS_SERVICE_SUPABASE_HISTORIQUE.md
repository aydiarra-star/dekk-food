# Écarts du service Supabase Flutter historique — DEKK FOOD

Date de vérification : 14 octobre 2026. Analyse statique du code et inventaire distant en lecture seule. Aucune migration ni modification de production.

## Écarts constatés

La relecture de `lib/services/supabase_service.dart` et `lib/models/restaurant.dart` a confirmé un second écart indépendant des UUID :

- le service demande `restaurants.is_active = true`, mais cette colonne n'apparaît pas dans l'inventaire distant du 14/10/2026 ;
- il lit `public.menu_items`, alors que la table historique présente est `public.restaurant_menus` ;
- le modèle Flutter assigne directement les identifiants JSON à des champs Dart `String`, alors que les identifiants distants sont des entiers ;
- il attend `title` pour un menu, tandis que la table historique expose `name`.

## Conséquence

Ce service historique ne doit pas être considéré comme un chemin Supabase fonctionnel sans test d'intégration et adaptation explicite. Le catalogue embarqué actuel demeure un chemin indépendant ; il ne faut pas le remplacer par ce service pendant la migration.

## Critère avant fusion

Décider explicitement soit de désactiver/documenter ce service tant qu'il n'est pas utilisé, soit d'ajouter un adaptateur testé qui traduit le schéma historique sans modifier les tables de production. Ne pas créer des colonnes ou tables à l'aveugle pour satisfaire le service.

## Architecture de compatibilité à prototyper

Préserver `public.restaurants`, `public.restaurant_menus`, `public.restaurant_reviews` et leurs identifiants entiers. Tester le catalogue UUID dans un espace distinct, avec ses propres tables, seed idempotent, clés étrangères et politiques RLS. Le prototype n'est pas une migration de production.

## Correctifs du contrat Flutter — 14 octobre 2026

Le service a été réaligné sur les noms de tables et colonnes relevés en lecture seule :

- liste : `public.restaurants`, sans filtre `is_active` (colonne absente) ;
- menus : `public.restaurant_menus`, filtrés avec l'ID numérique converti depuis la chaîne ;
- modèle restaurant : IDs numériques convertis en chaînes, `cuisine_types` traité comme liste, repli du quartier sur `city` ;
- modèle menu : `name` utilisé comme titre, IDs convertis en chaînes, prix numérique conservé.

Des tests Flutter de désérialisation ont été ajoutés dans `test/models/restaurant_test.dart`.

**Limite sécurité inchangée :** l'inventaire a trouvé RLS activé sans policies pour ces tables. Ces changements de code ne rendent pas les données lisibles par l'application publique à eux seuls. Aucune policy/grant n'a été modifiée ; il faudra concevoir et valider les droits séparément, avec des tests de rôle, avant tout changement de production.
