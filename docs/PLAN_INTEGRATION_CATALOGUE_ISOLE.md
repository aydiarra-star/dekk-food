# Plan d'intégration du catalogue isolé — sans migration de production

Date : 14 octobre 2026. Statut : plan de travail, aucune migration exécutable.

## État confirmé

- Le prototype `tools/tests/test_catalogue_isolation.py` réussit dans la CI sur PostgreSQL jetable.
- Le schéma historique réel observé sur Supabase utilise des identifiants entiers dans `public.restaurants`, `public.restaurant_menus` et `public.restaurant_reviews`.
- Le catalogue SQL actuel n'est pas isolé : le générateur `tools/catalogue/generation.py` émet des requêtes qualifiées `public.*` et dépend du référentiel, des sources et des tables relationnelles du même espace.
- Les migrations 0001–0007 sont conçues pour étendre `public.restaurants`, pas pour créer à elles seules un catalogue UUID autonome.

## Pourquoi un simple renommage de table ne suffit pas

Le générateur écrit dans les familles suivantes, à vérifier systématiquement lors du refactor :

- identité et géographie : `restaurants`, `regions`, `departements`, `communes`, `quartiers`, `types_etablissement` ;
- nomenclature et provenance : `categories_culinaires`, `services`, `allergenes`, `regimes_alimentaires`, `sources` ;
- relations d'établissement : `etablissement_categories`, `contacts`, `horaires`, `etablissement_services`, `zones_livraison`, `images` ;
- menus et plats : `menus`, `plats`, `plat_allergenes`, `plat_regimes` ;
- exploitation et traçabilité : `entreprises`, `etablissement_exploitation`, `etablissement_sources`.

Les migrations ajoutent également fonctions, triggers, vues, contraintes, politiques RLS et grants. Les déplacer de `public` vers un autre schéma exige de revoir leurs références croisées, leurs droits et les appels applicatifs.

## Ordre de travail recommandé

1. **Cartographier les consommateurs** : générateur, seed SQL généré, migrations, vues/fonctions, services Flutter, tests et éventuels appels PostgREST.
2. **Décider du modèle** : conserver sans changement les tables historiques ; isoler le nouveau catalogue et toutes ses tables dépendantes dans un schéma dédié, ou choisir explicitement une autre stratégie après comparaison. Ne pas mélanger des identifiants integer et UUID dans une même relation.
3. **Créer le schéma cible sur PostgreSQL jetable** : toutes les tables, clés, contraintes, fonctions et index nécessaires ; aucune dépendance implicite au schéma `public`.
4. **Adapter le générateur avec une cible explicite** : aucun remplacement textuel global de `public` ; les noms de schéma doivent être contrôlés/validés, et la cible par défaut ne doit pas permettre une écriture accidentelle en production.
5. **Générer le seed et tester** : première insertion, second passage, mise à jour par slug, conservation des données non publiées, absence de doublons dans les relations.
6. **Tester les accès** : rôle anonyme, utilisateur authentifié, restaurateur et administrateur ; lecture des seules fiches publiées ; isolation des données non publiées ; refus des écritures non autorisées ; vues/fonctions avec droits explicites.
7. **Adapter Flutter sans supprimer le chemin catalogue embarqué/hors ligne** : séparer le modèle historique du modèle catalogue ; tests de désérialisation integer/UUID et de noms de colonnes.
8. **Rejouer toute la CI** puis comparer les résultats et les volumes attendus. Refaire un inventaire Supabase en lecture seule juste avant toute proposition de migration.

## Critères d'acceptation avant fusion

- Tous les tests CI passent sur la dernière SHA.
- Le seed complet généré cible uniquement le schéma choisi et est idempotent.
- Les tests prouvent que les identifiants, lignes, avis et menus historiques ne changent pas.
- Les tests RLS/grants couvrent les rôles et chemins de lecture/écriture pertinents.
- Flutter et le catalogue hors ligne continuent à fonctionner.
- Une revue humaine approuve une migration distincte, avec sauvegarde et plan de retour arrière.

## Interdictions maintenues

Aucune migration, écriture SQL, modification de RLS/grants, seed ou changement de données sur Supabase de production pendant cette phase. Ne pas fusionner et ne pas déployer avant les critères ci-dessus.


## Première tranche de refactorisation livrée — générateur SQL

La fonction `generation.generer_sql(..., schema_cible="public")` accepte maintenant une cible explicite validée. La valeur par défaut reste strictement `public`, afin de ne pas modifier le seed existant lors des appels actuels. La qualification ne touche que les références SQL `public.` hors chaînes et commentaires ; les noms de schéma invalides sont refusés.

Tests dédiés : `tools/tests/test_schema_sql_target.py` couvre le comportement historique par défaut, la qualification du SQL généré vers `catalogue`, la validation du nom et la préservation des littéraux/commentaires. Les cas de protection incluent aussi les chaînes dollar-quotées PostgreSQL, les chaînes `E'…'` avec antislashs et les commentaires de bloc imbriqués. Le qualificateur reste un outil textuel ciblé, pas un parseur SQL complet.

**Portée limitée, non prête pour la production :** ce changement ne crée pas le schéma cible, ses tables, fonctions, contraintes, triggers, index, policies RLS ou grants. Il ne déplace pas les migrations et n'autorise pas l'exécution du seed vers `catalogue` tant que le schéma complet n'a pas été construit et testé dans PostgreSQL jetable. Le CLI et les migrations ne proposent pas encore de migration de production.

## Tranche suivante — cible explicite depuis la CLI

La commande `generer` accepte désormais `--schema-cible catalogue`. Le défaut reste `public`, et un test génère le seed dans un dossier temporaire pour vérifier que les requêtes utilisent `catalogue.*` sans toucher aux fichiers canoniques du dépôt. Exemple local, à utiliser uniquement pour produire un artefact de test :

```bash
python -m tools.catalogue.importateur generer data/seed/*.json --dossier /tmp/dekk-catalogue-test --schema-cible catalogue --date 2026-10-14
```

Cette option **ne crée pas** les tables, fonctions, vues, contraintes, policies ou privilèges du schéma cible. Elle ne doit donc pas servir à exécuter le seed dans une base réelle à ce stade.

### Blocage identifié avant le test complet des migrations

Les migrations contiennent du SQL dynamique construit dans des chaînes, par exemple dans la migration 0003 les appels `execute format('alter table public.%I ...')` et `execute format('create policy ... on public.%I ...')`. Le qualificateur de seed préserve volontairement les chaînes et ne réécrit donc pas ces références dynamiques. Les fonctions, vues et politiques de sécurité contiennent également des références croisées à contrôler. Appliquer simplement le qualificateur aux migrations laisserait des objets dans `public` et créerait un faux sentiment d'isolation.

Avant de tester l'ensemble des migrations dans le schéma `catalogue`, il faut choisir une méthode de migration explicite (migrations paramétrables par schéma ou adaptation contrôlée et auditée du SQL dynamique), puis vérifier dans PostgreSQL jetable les objets créés, les dépendances et les permissions effectives. Aucun changement de production n'est autorisé par cette étape.

