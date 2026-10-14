# Contrat de schéma du catalogue isolé — DEKK FOOD

Date : 14 octobre 2026  
Statut : inventaire technique préalable ; **ce document ne constitue pas une migration exécutable**.

## 1. But et frontière

Le nouveau catalogue doit vivre dans le schéma PostgreSQL `catalogue`, séparé du schéma historique `public`. Le schéma historique observé contient notamment `public.restaurants.id` et `public.restaurant_menus.restaurant_id` de type integer. Le modèle catalogue des migrations actuelles est construit autour d'identifiants UUID et de nombreuses tables liées.

**Interdiction de compatibilité implicite :** une clé entière de l'ancien modèle ne doit jamais être castée en UUID ni réutilisée comme identifiant du nouveau catalogue. Aucune FK du nouveau schéma ne doit pointer vers les tables historiques. Les migrations `0001–0007` restent inchangées et ne sont pas réutilisables telles quelles pour `catalogue`.

## 2. Dépendances du seed généré

Le générateur `tools/catalogue/generation.py` construit des instructions SQL explicitement qualifiées en `public.*`. Le paramètre `--schema-cible catalogue` ne fait que qualifier les références relationnelles du seed ; il ne crée ni les tables, ni les contraintes, ni les fonctions, ni les policies, ni les privilèges nécessaires.

Les familles d'objets directement référencées par le générateur doivent être prises en charge et vérifiées dans le schéma cible :

- **Établissements et géographie** : `restaurants`, `regions`, `departements`, `communes`, `quartiers`.
- **Référentiels** : `sources`, `types_etablissement`, `categories_culinaires`, `services`, `allergenes`, `regimes_alimentaires`.
- **Relations établissement** : `contacts`, `horaires`, `etablissement_categories`, `etablissement_services`, `zones_livraison`, `etablissement_sources`, `entreprises`, `etablissement_exploitation`.
- **Menus et médias** : `menus`, `plats`, `images`, `plat_allergenes`, `plat_regimes`.

Cette liste est la surface visible dans le générateur, pas une preuve que tous les objets sont inventoriés : les FK, triggers, fonctions, index, vues, policies et objets dynamiques des migrations doivent être cartographiés séparément avant de figer le contrat.

## 3. Contrat minimal pour la migration dédiée

La série dédiée doit :

1. Créer explicitement le schéma `catalogue` et qualifier chaque objet de façon non ambiguë.
2. Définir les tables, colonnes, types, valeurs par défaut, contraintes CHECK, clés uniques et FK réellement utilisées par le seed.
3. Maintenir des clés UUID cohérentes à l'intérieur du catalogue ; toute référence de table enfant doit cibler une table du schéma `catalogue`.
4. Préserver les règles de provenance : les informations confirmées doivent conserver une source traçable ; aucune image générique ne doit être présentée comme une photo authentique ; une fiche non publiable doit rester non publiée avec un motif.
5. Garantir l'idempotence du seed sur deux exécutions successives, sans doublons ni perte de données.
6. Définir la publication et les autorisations par défaut comme privées ; accorder les droits nécessaires table par table, puis activer et tester RLS. Un `GRANT` ne remplace pas une policy RLS et inversement.
7. Définir les fonctions nécessaires dans le bon schéma, avec toutes les références qualifiées et un `search_path` fixé. Ne pas recopier automatiquement les fonctions `SECURITY DEFINER` historiques.
8. Laisser les tables historiques, colonnes, contraintes, privilèges et données de `public` strictement inchangés.

## 4. Contrat de vérification PostgreSQL jetable

Le test d'intégration dédié devra démarrer avec des tables historiques `public` représentatives et des lignes témoins, puis :

- prendre une photographie de la structure et des données historiques ;
- appliquer uniquement les migrations dédiées au catalogue ;
- exécuter le seed catalogue deux fois ;
- vérifier les comptages, les clés uniques, les FK, les contraintes et la parité avec les fiches du catalogue source ;
- vérifier dans les catalogues système qu'aucun objet catalogue n'a été créé dans `public` ;
- rechercher toutes les FK de `catalogue` vers `public` et exiger zéro résultat ;
- tester les privilèges effectifs et la RLS avec les rôles `anon`, `authenticated` et le rôle administratif de test ;
- prouver que `anon` ne peut lire ni fiches non publiées, ni données historiques privées, ni vues internes ;
- comparer la photographie historique après migration et exiger une égalité exacte ;
- terminer en erreur au moindre contrôle non exécuté ou résultat inattendu. Un test sauté parce qu'une dépendance manque ne doit jamais compter comme un succès.

## 5. Séparation des modèles applicatifs

Le service Flutter actuellement documenté utilise le modèle historique : `restaurants` avec identifiants numériques et `restaurant_menus`. Le catalogue isolé UUID ne doit pas devenir la source de ce service par simple changement de schéma. Il faut une décision explicite de source, un adaptateur/modèle dédié et des tests de désérialisation séparés, tout en préservant le fonctionnement existant.

## 6. État et décision

- Les tests actuels valident les migrations historiques dans `public` sur PostgreSQL jetable.
- Le test de coexistence actuel est un POC limité ; il ne valide pas les migrations complètes.
- Le qualificateur de seed ne transforme pas le SQL dynamique des migrations et ne suffit pas à isoler les objets.
- **Aucune migration dédiée complète n'est déclarée prête à ce stade.**

Étape suivante obligatoire : traduire cet inventaire en DDL dédié, vérifier le contrat exact de chaque colonne contre le générateur, puis créer un test d'intégration PostgreSQL complet. Tant que ces tests ne sont pas verts, ne pas exécuter ce chemin sur Supabase réel.

## Garde-fous

Aucune connexion ni écriture Supabase de production. Aucun changement de données canoniques. Aucune migration historique modifiée pour simuler l'isolation. Aucune fusion de PR ni aucun déploiement sans autorisation explicite.


## 7. Inventaire exact des écritures émises par le générateur

Vérification du code de `tools/catalogue/generation.py` (fonction `generer_sql`, lignes 492–758 dans la révision auditée). Cette liste décrit les colonnes émises par le générateur ; elle ne remplace pas la validation des types, contraintes, FK et index du DDL cible.

| Table cible | Colonnes écrites par le seed | Conflit / idempotence attendu |
|---|---|---|
| `restaurants` | `numero_fiche, slug, name, nom_officiel, nom_commercial, cuisine_type, neighborhood, address, adresse_complete, phone, whatsapp, latitude, longitude, is_active, region_id, departement_id, commune_id, quartier_id, ville_libre, type_etablissement_id, description_courte, description_longue, statut, niveau_verification, gps_verifie, fourchette_prix_min, fourchette_prix_max, devise, ambiance, clientele, modes_paiement, accessibilite, equipements, site_web, facebook, instagram, commande_en_ligne_url, reservation_url, points_de_repere, source_principale_id, source_principale_url, date_collecte, derniere_verification_le, commentaire_verification, origine_donnee, est_publication_visible, motif_non_publication, statut_validation, validation_par, validation_le, image_principale_url` | `UNIQUE(slug)`, mise à jour des colonnes métier |
| `etablissement_categories` | `restaurant_id, categorie_id, est_principale` | `UNIQUE(restaurant_id, categorie_id)` |
| `contacts` | `restaurant_id, type, valeur, libelle, confirme, est_principal, source_id, source_url, date_collecte` | `UNIQUE(restaurant_id, type, valeur)` |
| `horaires` | `restaurant_id, jour, service, ferme, ouverture, fermeture, confirme, source_id, source_url, date_verification` | `UNIQUE(restaurant_id, jour, service)` |
| `etablissement_services` | `restaurant_id, service_id, confirme, source_id` | `UNIQUE(restaurant_id, service_id)` |
| `zones_livraison` | `restaurant_id, commune_id, libelle_zone, frais_livraison, devise, delai_estime, minimum_commande, confirme, source_id, source_url` | Conflit sur expression `(restaurant_id, coalesce(commune_id, 0), coalesce(libelle_zone, ''))` ; à vérifier impérativement contre le type de `commune_id` et un index unique correspondant |
| `images` | établissement : `restaurant_id, url, type_media, legende, est_principale, est_illustration_generique, correspondance_verifiee, auteur, licence, autorisation_usage, source_id, source_url, date_collecte, ordre`; plat : `plat_id, url, type_media, legende, est_illustration_generique, correspondance_verifiee, auteur, licence, autorisation_usage, source_id, source_url, date_collecte` | Conflit sur expression avec sentinelle UUID et `url` ; doit correspondre exactement à l'index unique dédié |
| `menus` | `restaurant_id, nom, type, statut, devise, source_id, source_url, date_collecte, date_debut, date_fin, derniere_maj` | `UNIQUE(restaurant_id, nom, type)` |
| `plats` | `restaurant_id, menu_id, nom, description, categorie, prix, devise, taille_portion, options, variantes, disponibilite, date_debut, date_fin, statut_confirmation, source_id, source_url, derniere_maj` | `UNIQUE(menu_id, nom)` |
| `plat_allergenes` | `plat_id, allergene_id` | Clé primaire `(plat_id, allergene_id)` |
| `plat_regimes` | `plat_id, regime_id` | Clé primaire `(plat_id, regime_id)` |
| `entreprises` | `raison_sociale, nom_commercial, source_id, source_url, date_verification, statut_confirmation` | Contrôle `NOT EXISTS` sur `raison_sociale`, sans contrainte d'idempotence prouvée par ce fragment |
| `etablissement_exploitation` | `restaurant_id, entreprise_id, role, source_id, source_url, date_verification, statut_confirmation` | Contrôle `NOT EXISTS` sur établissement, entreprise et rôle |
| `etablissement_sources` | `restaurant_id, source_id, url_exacte, date_collecte, donnees_collectees, niveau_confiance, collecte_par` | Conflit sur expression `(restaurant_id, source_id, coalesce(url_exacte, ''))`, à valider contre un index unique correspondant |

### Points bloquants révélés par cet inventaire

- Le seed utilise `validation_par::uuid` et une sentinelle UUID pour l'unicité des images. Les types de clés et les colonnes doivent donc être décidés explicitement dans le nouveau modèle ; on ne peut pas déduire un DDL sûr du seul nom des colonnes.
- Les expressions `ON CONFLICT` sur `zones_livraison`, `images` et `etablissement_sources` exigent des index/contraintes uniques compatibles, y compris les expressions exactes. Une contrainte unique classique ne suffit pas nécessairement.
- Le générateur ne crée pas de ligne dans `sources`, `regions`, `departements`, `communes`, `quartiers`, `types_etablissement`, `categories_culinaires`, `services`, `allergenes` ou `regimes_alimentaires` : ces référentiels doivent être préremplis ou alimentés par une migration/seed de référence avant les établissements, et les sélections doivent être testées contre des noms/codes réels.
- Ce seed n'écrit pas dans toutes les tables du modèle historique : le DDL catalogue doit partir des besoins du catalogue, pas d'une copie aveugle de toutes les migrations historiques.
- L'inventaire est statique et issu du code source. Il ne constitue pas encore une validation par exécution de la totalité des variantes SQL générées (contacts, horaires, menus, images, etc.) sur PostgreSQL jetable.

**Décision maintenue :** aucun DDL dédié n'est déclaré prêt avant d'avoir défini le modèle cible, ajouté les référentiels nécessaires, puis exécuté un seed représentatif deux fois dans PostgreSQL jetable avec assertions de schéma, clés, RLS et invariance de `public`.
