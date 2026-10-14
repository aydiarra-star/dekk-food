# Stratégie d'intégration du catalogue isolé — DEKK FOOD

Date : 14 octobre 2026  
Statut : décision technique proposée, sans exécution sur Supabase.

## Décision recommandée

Ne pas tenter de déplacer les migrations 0001–0007 par remplacement de texte. Elles étendent explicitement `public.restaurants`, qualifient de nombreuses dépendances en `public.*`, construisent des policies par SQL dynamique et configurent des fonctions `SECURITY DEFINER` avec un `search_path` qui vise `public`.

La voie la moins risquée est de conserver les migrations historiques intactes et d'écrire une série dédiée au nouveau schéma `catalogue`, conçue dès le départ pour cette cible. Cette série doit être autonome et ne doit pas modifier `public.restaurants`, `public.restaurant_menus` ou `public.restaurant_reviews`.

## Étapes d'implémentation

1. **Inventaire du contrat applicatif** : dresser la liste des colonnes effectivement lues/écrites par le générateur SQL, les services Flutter et les vues PostgREST. Séparer le modèle historique integer du modèle catalogue UUID.
2. **Migration initiale dédiée** : créer explicitement `catalogue` et les tables minimales nécessaires au seed. Les clés étrangères entre les nouvelles tables restent dans `catalogue`; aucune FK ne cible une table historique `public.*`.
3. **Fonctions et déclencheurs** : définir chaque fonction dans `catalogue`, qualifier ses dépendances et figer un `search_path` sûr. Aucune fonction `SECURITY DEFINER` ne doit dépendre d'une résolution implicite.
4. **RLS et privilèges** : accorder `USAGE` sur `catalogue` uniquement aux rôles requis, accorder des droits table par table, et vérifier les accès avec les rôles réellement disponibles. Une policy ne remplace pas un GRANT et un GRANT ne remplace pas une policy.
5. **Seed ciblé** : générer le seed vers un répertoire temporaire avec `--schema-cible catalogue`. Ne jamais écraser le seed canonique ni exécuter ce seed sur une base réelle pendant cette phase.
6. **Intégration PostgreSQL jetable** : installer d'abord un petit schéma historique représentatif dans `public`, y insérer des données de contrôle, appliquer uniquement les nouvelles migrations `catalogue`, exécuter le seed deux fois puis vérifier le contenu, l'idempotence, les FK, les objets de sécurité et les droits.
7. **Tests de non-régression** : comparer avant/après les lignes, colonnes et identifiants historiques ; vérifier que les rôles non autorisés ne peuvent pas lire les fiches privées ni accéder aux tables historiques.
8. **Intégration Flutter** : choisir explicitement le modèle et la source de données utilisés. Conserver le chemin de catalogue embarqué/hors ligne et ajouter des tests de désérialisation pour les deux modèles.
9. **Revue distincte** : avant toute proposition de migration réelle, produire un inventaire en lecture seule de Supabase, un plan de sauvegarde/restauration et un plan de retour arrière. Cette phase ne vaut pas autorisation d'exécuter la migration.

## Critères de validation du test PostgreSQL

Le test d'intégration doit échouer si l'une des conditions suivantes est vraie :

- une nouvelle table, vue, séquence, fonction ou policy du catalogue est créée dans `public` ;
- une FK du catalogue pointe vers les tables historiques `public.*` ;
- une migration catalogue modifie ou supprime une table/colonne historique ;
- le seed échoue au deuxième passage ou produit des doublons ;
- le rôle anonyme peut lire des fiches non publiées ou les tables historiques ;
- un rôle sans privilège peut écrire dans le catalogue ou exécuter une fonction administrative ;
- une fonction `SECURITY DEFINER` n'a pas de `search_path` fixé et vérifié ;
- les résultats ou identifiants des données historiques diffèrent de la photographie prise avant les migrations.

## État du contrôle actuel

La CI vérifie déjà les migrations 0001–0007 sur une instance PostgreSQL jetable dans leur cible historique `public`. Le test `tools/tests/test_catalogue_isolation.py` prouve la coexistence de tables historiques integer et d'une table catalogue UUID minimale, avec RLS et seed idempotent.

Ces tests ne prouvent pas encore que les migrations complètes 0001–0007 peuvent s'appliquer à `catalogue`. Le rapport statique identifie au contraire des références explicites et dynamiques à `public`. Le test d'intégration complet ne doit être déclaré prêt qu'après l'écriture des migrations dédiées ci-dessus ; un test qui ne fait que réécrire les chaînes SQL donnerait une assurance trompeuse.

## Garde-fous

- Aucune connexion ni écriture sur Supabase de production.
- Aucune application des migrations 0001–0007 en production.
- Aucun remplacement global de `public.`.
- Aucun changement de schéma, seed ou données canoniques dans cette étape.
- Aucune fusion de PR et aucun déploiement sans autorisation explicite.
