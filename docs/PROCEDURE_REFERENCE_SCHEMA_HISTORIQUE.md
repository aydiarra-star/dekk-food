# Procédure sûre — référence du schéma historique DEKK FOOD

Date : 14 octobre 2026  
Statut : procédure préparatoire ; aucune connexion ni opération de base n'a été exécutée.

## Objectif

Établir une référence vérifiable du schéma historique avant de concevoir les migrations du schéma `catalogue`. Le schéma versionné dans le dépôt et les hypothèses des tests ne concordent pas encore sur les types d'identifiants et les tables de menus. Ne pas choisir arbitrairement entre ces sources.

## Voie recommandée : export fourni par une personne autorisée

Demander un export **schema-only** réalisé avec une identité de base en lecture seule, puis transmettre le fichier par un canal privé adapté. Ne jamais ajouter l'URL de connexion, un mot de passe, un jeton, des données métier ou un dump complet au dépôt Git.

Exemple de commande à exécuter uniquement par la personne autorisée, dans son environnement sécurisé :

```sh
umask 077
pg_dump --schema-only --no-owner --no-privileges \
  --format=plain --file=historique-schema-only.sql \
  "$DEKK_FOOD_READ_ONLY_DATABASE_URL"
```

- La variable doit être configurée dans l'environnement sécurisé de la personne qui réalise l'export ; ne pas coller sa valeur dans un terminal partagé, un ticket ou le dépôt.
- Utiliser une identité strictement en lecture seule. Ne pas lancer de migration, de seed, de `psql -f` ou de commande d'écriture sur une base distante.
- L'option `--schema-only` exclut les lignes métier ; `--no-owner --no-privileges` évite d'exporter les propriétaires et ACL de l'instance. Ces options ne garantissent pas que le texte ne contienne aucun nom interne : relire et expurger avant tout partage.
- Si aucun accès autorisé n'est disponible, fournir plutôt un export schema-only déjà existant ou confirmer explicitement qu'une fixture synthétique non exhaustive sera utilisée. Ne pas fabriquer une fixture en prétendant qu'elle reflète la production.

## Contrôles à effectuer sur le fichier reçu

Avant de le considérer comme référence, vérifier et consigner :

1. **Provenance** : qui l'a produit, date, environnement/source, version PostgreSQL et confirmation qu'il s'agit d'un export sans données.
2. **Relations** : tables, tables partitionnées, vues, vues matérialisées, séquences et types personnalisés du schéma `public`.
3. **Colonnes** : types exacts, nullabilité, valeurs par défaut, identité/serial et ordre des colonnes.
4. **Intégrité** : clés primaires, uniques, CHECK, clés étrangères et actions `ON DELETE`.
5. **Comportement** : fonctions, procédures, triggers, extensions requises et SQL dynamique.
6. **Sécurité** : activation/forçage RLS, policies, grants et fonctions `SECURITY DEFINER` avec leur `search_path`.
7. **Désaccords à résoudre** : types de `restaurants.id`, `restaurant_menus.restaurant_id`, existence/type de `menu_items.restaurant_id`, existence de `restaurant_reviews`, ainsi que les relations réellement consommées par l'application Flutter.

La référence n'est acceptée qu'après rapprochement de cet inventaire avec `supabase/schema.sql`, les migrations `0001–0007`, les contrats de compatibilité et les requêtes de l'application. Documenter chaque divergence ; ne pas les masquer par un remplacement lexical global.

## Artefacts à conserver

- Le fichier source partagé doit rester hors du dépôt s'il contient des noms ou éléments sensibles.
- Dans le dépôt, conserver uniquement un rapport d'inventaire expurgé : objets et types nécessaires, divergences, provenance générale et empreinte SHA-256 du fichier d'origine si cela est autorisé.
- Une fixture synthétique dérivée de cette référence doit être explicitement étiquetée comme fixture de test, sans données personnelles et sans identifiants réels.

## Porte de sécurité avant les migrations

Les migrations dédiées ne peuvent commencer qu'après validation du rapport. Elles devront être autonomes dans `catalogue`, n'avoir aucune FK vers `public`, puis réussir les tests PostgreSQL jetables qui prouvent l'invariance de la fixture historique, y compris fonctions, policies, triggers, ACL, séquences et données.

## Interdictions

- Aucun accès ni aucune écriture Supabase de production dans cette étape.
- Aucun secret ou dump de données dans GitHub.
- Aucune modification des migrations historiques `0001–0007`.
- Aucun remplacement global de `public.`.
- Aucun merge ou déploiement sans autorisation explicite.
