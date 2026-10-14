# Contrat de test — isolation complète du catalogue DEKK FOOD

Statut : spécification de test, pas une validation d'isolation. À utiliser sur une instance PostgreSQL jetable uniquement.

## Objectif

Prouver que le nouveau catalogue UUID peut être créé, alimenté et interrogé sans altérer les tables historiques public.restaurants, public.restaurant_menus et public.restaurant_reviews (IDs entiers), et sans que les objets du nouveau catalogue dépendent implicitement de ces tables.

## Fixture historique immuable

Créer dans la base jetable les trois tables historiques avec leur structure réelle, leurs clés étrangères et au moins :
- un restaurant avec un ID entier explicite ;
- un menu rattaché à ce restaurant ;
- un avis rattaché à ce restaurant.

Capturer avant l'installation du catalogue : colonnes/types, contraintes, index, lignes complètes et valeurs de séquence/identity. Capturer à nouveau après chaque étape et comparer exactement. Toute différence non prévue fait échouer le test.

## Contrat des migrations catalogue

Les migrations dédiées doivent être une série autonome et ordonnée. Le test doit appliquer uniquement cette série, sans appliquer les migrations historiques public comme si elles étaient paramétrables.

Pour chaque migration, contrôler :
- création dans le schéma cible uniquement ;
- tables, colonnes, types, valeurs par défaut, contraintes, clés primaires/étrangères et index ;
- vues et vues matérialisées ;
- fonctions et procédures, y compris leur search_path et SECURITY DEFINER ;
- triggers et fonctions associées ;
- politiques RLS, activation de RLS et FORCE ROW LEVEL SECURITY le cas échéant ;
- privilèges effectifs de anon, authenticated, restaurateur, administrateur et rôle de service ;
- absence de références involontaires au schéma public dans les dépendances du catalogue, SQL dynamique, vues, fonctions et politiques.

Un simple comptage des tables ne suffit pas. Une recherche textuelle de public. ne suffit pas non plus : les fonctions, chaînes SQL dynamiques, politiques et privilèges doivent être vérifiés via les catalogues PostgreSQL et des tests d'exécution.

## Contrat du seed

Générer le seed complet dans un répertoire temporaire en ciblant explicitement le schéma isolé. Exécuter le seed deux fois, puis vérifier :
- même nombre de fiches et mêmes slugs uniques ;
- pas de doublon dans les relations ;
- mises à jour déterministes des fiches déjà présentes ;
- aucune publication involontaire d'une fiche non publiée ;
- toutes les clés étrangères valides ;
- aucune écriture dans les trois tables historiques.

Le seed de production canonique ne doit pas être réécrit par le test.

## Contrat de sécurité

Exécuter des requêtes avec les rôles réels dans la base jetable, sans rester superutilisateur :
- anon ne lit que les fiches publiées et ne peut pas lire les données privées/historiques ;
- authenticated ne peut pas écrire hors de ses autorisations ;
- un restaurateur ne peut modifier que les établissements qui lui sont attribués ;
- un administrateur peut effectuer les opérations documentées ;
- le rôle de service dispose uniquement des privilèges requis par l'architecture ;
- les fonctions SECURITY DEFINER ne contournent pas les règles attendues via un search_path dangereux.

Les tests doivent vérifier les résultats et les refus attendus, pas seulement la présence des policies ou des GRANT.

## Contrat Flutter

Garder le catalogue embarqué/hors ligne fonctionnel. Tester séparément les modèles historiques à IDs entiers et les modèles catalogue UUID ; vérifier que les erreurs de connexion Supabase ne bloquent pas l'expérience hors ligne.

## Critère de sortie

La validation ne peut être annoncée que si :
1. les migrations catalogue complètes existent ;
2. ce contrat est couvert par des tests automatisés exécutés sur PostgreSQL jetable ;
3. tests Python, analyse/tests Flutter et build web réussissent sur le même SHA ;
4. l'empreinte des trois tables historiques est inchangée ;
5. aucune opération n'a été exécutée sur Supabase de production.

Aucune migration de production, modification de RLS/grants, fusion ou déploiement n'est autorisé par ce contrat.