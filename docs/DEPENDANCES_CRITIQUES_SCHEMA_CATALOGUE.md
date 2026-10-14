# Dépendances critiques pour l'isolation du catalogue

Cette note complète l'audit statique. Elle localise les endroits où un simple remplacement de `public.` ne suffit pas. Les numéros de ligne ci-dessous correspondent au HEAD `6b0d4b976540d7d58cbeb20804eb8ae7162bebde` de la branche de travail ; ils peuvent évoluer avec les migrations.

## Points à traiter avant une migration vers `catalogue`

| Migration | Lignes / motif | Pourquoi c'est bloquant |
| --- | --- | --- |
| `0001_referentiel_et_catalogue.sql` | 17, 22 : `CREATE EXTENSION` | Les extensions ont leur propre emplacement et leurs opérateurs/fonctions peuvent être hors du schéma cible. La disponibilité et les droits doivent être vérifiés sur l'instance de test. |
| `0002_menus_images_services.sql` | vers 398 : `SECURITY DEFINER` | La fonction doit avoir un `search_path` sûr et les références doivent viser les objets corrects dans le schéma cible. |
| `0003_securite_vues_admin.sql` | 82–85 : `GRANT` sur `schema public`, tables et séquences | Ces permissions sont actuellement globales à `public`; elles ne donnent pas automatiquement accès au nouveau schéma et ne doivent pas exposer le schéma historique. |
| `0003_securite_vues_admin.sql` | 105–117, 180–181 : `format()` et `public.%I` dans SQL dynamique | Le qualificateur de seed laisse intentionnellement les chaînes et corps dollar-quotés intacts. Ces politiques continueraient donc à viser `public` après un remplacement lexical extérieur. |
| `0004_publication_validation_provenance.sql` | 277–281 : `REVOKE` sur vues/fonctions | Les objets et droits ciblés doivent correspondre au schéma cible, sans changer le sens du mot-clé de rôle `PUBLIC`. |
| `0005_cloisonnement_public.sql` | 45–50 : politiques construites avec `format()` | Le nom de la table cible est construit à l'exécution; la requête dynamique doit être adaptée et testée, pas seulement le SQL extérieur. |
| `0006_acces_admin_restaurateur.sql` | 43–74, 128–130 : fonctions `SECURITY DEFINER`, `search_path`, politiques dynamiques | L'identité et le périmètre du restaurateur dépendent de fonctions et tables du catalogue; leur résolution doit être explicite et leurs droits réévalués. |
| `0007_securite_vues_et_fonctions.sql` | 77–79, 467–472, 693–738 : grants, SQL dynamique, `search_path`, révocations | La migration finale redéfinit les privilèges et chemins de recherche pour de nombreux objets. Un changement partiel peut donner l'illusion de sécurité tout en ciblant le mauvais schéma. |

## Conclusion technique

Le générateur `qualifier_schema_sql()` a été conçu pour le SQL du seed et préserve les chaînes, commentaires et corps dollar-quotés. Il ne doit **pas** être réutilisé comme transformateur général des migrations. Il faut une stratégie distincte, revue migration par migration, ou des migrations rendues paramétrables avec des identifiants de schéma contrôlés.

Le futur test d'intégration devra exécuter toutes les migrations dans une instance PostgreSQL jetable, puis vérifier les tables, contraintes, fonctions, vues, triggers, politiques RLS et privilèges effectifs. Tant que ce test n'existe pas et ne passe pas, l'isolation n'est pas considérée comme validée.

## Barrière de sécurité maintenue

- Pas d'application des migrations 0001–0007 sur Supabase production.
- Pas de remplacement global de `public.`.
- Pas de fusion de la PR ni de déploiement automatique.
