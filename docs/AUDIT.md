# DEKK FOOD / DAKA FOOD — Audit du projet existant

Date de l'audit : 13 octobre 2026
Périmètre : dépôt `aydiarra-star/dekk-food`, branche auditée `main` (commit `b8930a3`).

---

## 1. Ce qui existe réellement aujourd'hui

| Élément | État constaté | Fichier |
|---|---|---|
| Application | Flutter (Material 3, thème `deepOrange`), cible web déployée sur GitHub Pages | `pubspec.yaml`, `lib/main.dart` |
| Point d'entrée | `main.dart` monolithique de 1 576 lignes contenant **toutes** les classes : modèle panier, navigation, 4 écrans d'onglets, 3 écrans de détail, checkout | `lib/main.dart` |
| Données | **Liste Dart en dur** de 14 établissements (`const List<Map<String, dynamic>>`) avec, pour chacun, 1 à 2 plats en dur | `lib/main.dart` lignes 127–520 |
| Modèles | `Restaurant` et `MenuItem` (champs : id, name, cuisine_type, neighborhood, address, phone, whatsapp, lat, lng, price, description, category) | `lib/models/restaurant.dart` |
| Accès données | `SupabaseService` : `getRestaurants()`, `getMenuItems()` — **jamais appelé** dans l'application | `lib/services/supabase_service.dart` |
| Base de données | 2 tables : `restaurants`, `menu_items` | `supabase/schema.sql` |
| Déploiement | Workflow GitHub Pages (`flutter build web --release --base-href=/dekk-food/`) déclenché sur `push` vers `main` uniquement | `.github/workflows/deploy.yml` |
| Tests | **Aucun** (ni `test/`, ni analyse statique en CI) | — |

Fonctionnalités réellement opérationnelles dans l'application : recherche texte (nom/quartier/zone/cuisine), filtre par 5 zones
(Dakar, Rufisque, Diamniadio/AIBD, Petite Côte), fiche établissement, fiche plat, panier (1 restaurant à la fois),
checkout avec génération d'un message WhatsApp, historique de commandes en mémoire, écran favoris **vide**, écran paramètres statique.

## 2. Problèmes constatés (classés par gravité)

### 2.1 Bloquants techniques

1. **`url_launcher` est importé mais absent de `pubspec.yaml`.** `lib/main.dart` ligne 2 importe
   `package:url_launcher/url_launcher.dart`, utilisé pour « Appeler », « WhatsApp » et « GPS ».
   La dépendance n'existe ni dans `dependencies` ni dans un fichier de lock → **la compilation échoue**.
   *(À noter : le dernier run GitHub Actions est en succès, donc soit le fichier en ligne diffère, soit la
   résolution a échoué silencieusement — à corriger dans tous les cas.)*
2. Aucun fichier `pubspec.lock` committé, aucune contrainte de version sur `supabase_flutter`.
3. Aucun test, aucune analyse statique : les régressions ne sont pas détectées avant déploiement en production.

### 2.2 Bloquants « données » au regard du cahier des charges

4. **Les données ne sont pas dans une base** mais dans le code source : aucun ajout d'établissement sans redéploiement.
5. **Couverture nationale absente** : 14 établissements, 4 zones (Dakar, Rufisque, Diamniadio/AIBD, Petite Côte).
   Aucune donnée pour 12 des 14 régions (Diourbel, Fatick, Kaffrine, Kaolack, Kédougou, Kolda, Louga, Matam,
   Saint-Louis, Sédhiou, Tambacounda, Ziguinchor).
6. **Aucune hiérarchie géographique** : le champ `neighborhood` est du texte libre (« Ngor », « Almadies »…),
   sans région, département, commune ni quartier normés. Les filtres ne peuvent pas descendre à l'échelon administratif.
7. **Données fabriquées publiées comme authentiques** — non conforme au §6 et §14 du cahier des charges :
   - les photos sont des **images de banque (Unsplash)** présentées comme les plats réels des établissements
     (ex. « Gambas grillées » pour Seven Seven) ;
   - plusieurs plats portent un encadré vert « **Garantie Hygiène & Propreté** » avec des affirmations
     (« normes HACCP », « cuisines désinfectées en continu ») qui ne proviennent d'aucun contrôle réel ;
   - les notes et volumes d'avis (`4.8`, `2 122 avis`) sont des valeurs en dur sans source ;
   - des numéros de téléphone et des prix sont en dur sans source, certains manifestement génériques
     (`+221 33 825 12 34`, `+221 77 111 22 33`).
   - `N’Gor Bi`, `Le Cozy`, `Le Patio`, `Diamniadio Express Diner`, `La Halte AIBD`, `La Kaz’ Mbour`,
     `Le Pelican Ngaparou`… sont **introuvables dans les sources consultées** : ils ne peuvent pas être publiés
     comme établissements vérifiés (voir `docs/SOURCES.md`).
8. **Aucune traçabilité** : ni source, ni date de collecte, ni niveau de vérification pour aucun champ.

### 2.3 Manques fonctionnels (demandés, non présents)

9. Pas de filtres par région / budget / service / livraison ; pas d'accès à la hiérarchie géographique.
10. Pas de **carte interactive** (le bouton « GPS » ouvre un lien de recherche Google Maps externe).
11. Pas de **carte de menus structurée** (plat = dictionnaire non typé, pas de catégorie normalisée, pas de
    disponibilité, pas de période de promotion, pas de source).
12. **Favoris vides** (écran factice), pas d'avis, pas de signalement d'erreur, pas de suggestion d'établissement,
    pas de demande de correction.
13. Pas d'**espace professionnel** (revendication de fiche, publication de menu).
14. Pas d'**administration** (couverture, qualité, file de travail, doublons).
15. Pas d'**import de masse** (CSV/XLSX/JSON), pas de détection de doublons, pas de géocodage contrôlé.
16. Le panier ne mémorise pas les options, et aucun mode de commande (retrait/livraison/partenaire) n'est distingué.
17. Les zones de livraison, modes de paiement, accessibilité, horaires, ambiances, propriétaires : inexistants.

### 2.4 Ce qui fonctionne et doit être préservé

- Le parcours **Découvrir → fiche → plat → panier → checkout WhatsApp → historique** est complet et cohérent.
- L'identité visuelle (`deepOrange`, Material 3, fond `#F3F4F6`), les libellés français, la navigation à 4 onglets.
- Le panier mono-restaurant avec garde-fou de changement de restaurant (dialogue de confirmation).
- La génération du message WhatsApp de commande et l'écran de succès.
- Le workflow de déploiement GitHub Pages (`main`, `--base-href=/dekk-food/`).

## 3. Écarts avec le cahier des charges national

| Exigence | État initial | Action menée |
|---|---|---|
| Couverture 14 régions | 4 zones | Référentiel 14 régions / 46 départements + collecte progressive multi-sources |
| Hiérarchie géographique | texte libre | Tables `regions`, `departements`, `communes`, `quartiers` |
| Base de données adaptée | 2 tables | Schéma étendu (voir `docs/ARCHITECTURE_DONNEES.md`) |
| Sources et dates | aucune | `sources`, `etablissement_sources`, `verifications` |
| Menus / plats / prix | 1 plat en dur par établissement | `menus`, `menu_sections`, `plats`, `plats_promotions` |
| Images et droits | URL Unsplash sans mention | `images` avec licence, auteur, autorisation, `est_illustration_generique` |
| Contacts pro | 2 champs | `contacts` typés + boutons appel/WhatsApp/itinéraire |
| Horaires | aucun | `horaires`, `horaires_exceptionnels` |
| Services et livraison | aucun | `services`, `etablissement_services`, `zones_livraison` |
| Propriété / société | aucun | `entreprises`, `gestionnaires`, `etablissement_exploitation` (avec obligation de source) |
| Import de masse | aucun | `tools/catalogue` (CSV/XLSX/JSON, validation, dédoublonnage, rapport) |
| Administration | aucune | Écran admin Flutter + vues SQL de couverture/qualité/file de travail |
| Avis, signalements, revendications | aucun | `avis`, `signalements`, `demandes_correction`, `revendications` |
| Tests | aucun | Tests Python (pipeline données) + tests Dart + CI |

## 4. Modifications retenues (incrémentales, sans réécriture)

1. **Conserver** `lib/main.dart` (thème, panier, checkout, navigation) mais **éclater** les écrans dans `lib/screens/`.
2. **Corriger** `pubspec.yaml` (ajout `url_launcher`, `shared_preferences`, `flutter_map`, `latlong2`).
3. **Faire évoluer** la table `restaurants` existante (ALTER + nouvelles tables) au lieu de créer une base concurrente.
4. **Externaliser les données** dans `data/seed/*.json` (source unique de vérité) → génération de
   `assets/data/catalogue.json` (application) et `supabase/seed/*.sql` (base).
5. **Réétiqueter honnêtement** les contenus non sourcés hérités (photos de banque, encadrés « hygiène », notes
   d'avis) : conservation des données, mais statut `à confirmer` visible par l'utilisateur.
6. **Ajouter** carte interactive, filtres nationaux, favoris persistants, avis modérés, signalements,
   espace professionnel, administration, import de masse, CI.

## 5. Contraintes de l'environnement d'exécution (transparence)

- Le sandbox **n'a pas de SDK Flutter/Dart** et ne peut pas télécharger les artefacts du SDK (hôtes réseau non
  autorisés). La compilation Flutter ne peut donc pas être exécutée ici : elle est vérifiée par
  **GitHub Actions** (`.github/workflows/ci.yml`, `flutter analyze` + `flutter test`), seule mécanique déjà
  prévue par le projet.
- PostgreSQL **est** disponible localement (binaire embarqué) : le schéma, les migrations, le seed et les vues
  d'administration sont appliqués et interrogés réellement (voir `docs/RAPPORT.md` §Tests).
- Le pipeline données Python est exécuté et testé localement.
