# Décision préalable — fixture historique du catalogue DEKK FOOD

Date : 14 octobre 2026  
Statut : blocage explicite avant toute migration dédiée.

## Pourquoi la fixture ne doit pas être inventée

Deux contrats incompatibles coexistent dans les éléments actuellement disponibles :

- Le fichier versionné `supabase/schema.sql` définit `public.restaurants.id` comme UUID et `public.menu_items.restaurant_id` comme une référence UUID vers `public.restaurants(id)`.
- Le contrat de compatibilité historique utilisé par les tests et les notes de migration décrit une base existante avec `public.restaurants.id`, `public.restaurant_menus.restaurant_id` et `public.restaurant_reviews.restaurant_id` de type entier.

Le schéma versionné n'est donc pas une source suffisante pour fabriquer une fixture dite « fidèle à la production ». Le POC de `tools/tests/test_catalogue_isolation.py` crée seulement trois tables minimales et ne prétend pas reproduire l'intégralité de la base réelle.

## Décision

Ne pas créer les migrations complètes du schéma `catalogue` à partir d'une hypothèse sur les tables historiques. D'abord établir la structure de référence de façon vérifiable, sans modifier la base.

La fixture doit être construite depuis un export **schéma uniquement**, obtenu en lecture seule et expurgé de toute donnée personnelle ou secrète. À défaut d'accès à une source de référence vérifiée, conserver une fixture de compatibilité explicitement étiquetée « minimale/non exhaustive » et ne jamais présenter son résultat comme preuve d'isolation en production.

## Contenu requis de la référence

- tables, vues, vues matérialisées, séquences et types ;
- colonnes, types, valeurs par défaut, contraintes, clés étrangères et index ;
- fonctions/procédures, triggers et dépendances ;
- politiques RLS, activation et mode FORCE RLS ;
- privilèges du schéma, tables, séquences et fonctions ;
- version PostgreSQL et extensions installées ;
- type exact des identifiants et relations des tables historiques concernées.

Aucune ligne métier ni aucun secret d'environnement ne doit être inclus dans l'export de référence. Pour comparer la conservation des données, utiliser séparément une fixture synthétique contenant des données témoins fictives.

## Conditions de sortie

1. Le schéma de référence est explicitement identifié et approuvé.
2. La fixture synthétique couvre les objets historiques réellement nécessaires au test.
3. Les migrations dédiées créent uniquement les objets voulus dans `catalogue`.
4. Le harness vérifie structure, données témoins, séquences, fonctions, triggers, politiques, ACL et clés étrangères inter-schémas.
5. Les tests RLS/grants s'exécutent avec des rôles non-superutilisateurs.
6. CI verte sur le commit qui contient la fixture et les migrations dédiées.

Jusqu'à satisfaction de ces conditions, le résultat doit rester « prototype de test », pas « isolation complète prouvée ».

## Garde-fous

- Aucune connexion ni écriture sur Supabase de production dans ce chantier.
- Ne pas appliquer les migrations historiques `0001–0007` au nouveau schéma par remplacement lexical.
- Ne pas modifier le schéma historique pour faire passer le test.
- Aucune fusion de PR ni aucun déploiement sans autorisation explicite.
