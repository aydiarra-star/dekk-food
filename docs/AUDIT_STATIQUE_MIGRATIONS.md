# Audit statique des dépendances de schéma — migrations DEKK FOOD

## But

Avant de déplacer le catalogue vers un schéma isolé (catalogue), l'audit recense des marqueurs de dépendance dans les migrations SQL : références qualifiées public., SQL dynamique visant public.%I, fonctions SECURITY DEFINER, search_path, policies RLS, permissions et extensions.

Commande depuis la racine du dépôt :

    python tools/catalogue/audit_migrations.py
    pytest tools/tests/test_migration_schema_audit.py

Le script est en lecture seule : il ne réécrit ni n'exécute les migrations. Les comptes sont lexicaux et servent de signal de risque, pas de preuve de validité syntaxique. Les chaînes, commentaires et corps dollar-quotés peuvent contenir des occurrences qui nécessitent une revue humaine. Le motif de SQL dynamique est volontairement une heuristique limitée.

## Mode strict

    python tools/catalogue/audit_migrations.py --schema-cible catalogue --strict

Le mode strict retourne le code 2 tant qu'il reste des références lexicales à public. Avec les migrations actuelles, c'est un résultat attendu : il évite de présenter le générateur de seed comme une isolation complète.

## Garde-fous avant adaptation

- Ne pas appliquer les migrations 0001–0007 à Supabase production : le schéma historique y utilise des identifiants entiers, alors que le modèle catalogue attendu utilise des UUID.
- Ne pas remplacer globalement public. dans les fichiers SQL. Les migrations utilisent du SQL dynamique, des vues, des fonctions, des politiques RLS, des droits, des références à auth.uid() et des dépendances d'extensions.
- Toute adaptation doit être testée sur PostgreSQL jetable, en comparant les objets et les privilèges créés et en vérifiant que les tables public.* historiques restent intactes.
- L'audit statique est une étape de découverte. Il ne vaut ni test d'intégration, ni validation de RLS/grants, ni autorisation de migration.

## Étape suivante

Construire une suite d'intégration isolée et une stratégie de migration explicite, puis adapter les migrations en préservant leur ordre et en testant les objets créés. Ne pas générer un patch automatique basé uniquement sur les résultats de ce rapport.
