# Rapport DEKK FOOD — ce qui est livré, ce qui reste

**Date de ce rapport : 2026-10-13** — branche `arena/c3d3f8c4-dekk-food`.
Chiffres mesurés par le pipeline à cette date, sans arrondi complaisant.

---

## 1. Ce qui est livré et vérifiable

### 1.1 Base de données (PostgreSQL / Supabase) — livrée et testée

| Élément | État |
|---|---|
| Schéma hérité conservé (`supabase/schema.sql`) | Conservé, non remplacé |
| Migrations `0001` → `0003` (référentiel, catalogue, menus/images/services, sécurité et vues admin) | Écrites et appliquées sur un PostgreSQL réel |
| Référentiel national | **14 régions, 46 départements**, communes et quartiers, 23 types, 30 catégories, 24 services, 13 allergènes, 7 régimes, **9 sources** |
| Table centrale `restaurants` étendue (≈ 40 colonnes) | Numéro de fiche, slug, statuts, niveaux de vérification, géolocalisation, contacts, prix, sources |
| Traçabilité | `etablissement_sources` (source + date + niveau de confiance), `journal_modifications`, `import_lots` |
| Contraintes de qualité | 6 insertions interdites **refusées par la base** (prix confirmé sans source, image générique présentée comme authentique, propriétaire confirmé sans source, fiche publiée sans région, zone de livraison confirmée sans source, compte restaurateur sans établissement) |
| Sécurité | Rôles `anon`/`authenticated`/`service_role` créés si absents, RLS activée, le niveau de vérification n'est pas modifiable par un restaurateur (trigger + RLS) |
| Vues d'administration | `v_qualite_catalogue`, `v_couverture_par_region/ville/categorie`, `v_file_travail`, `v_doublons_a_examiner`, `v_etablissements_publics`, `v_plats_publics` |
| Idempotence | Schéma + seed appliqués **deux fois** sans erreur |

Vérification reproductible :
```bash
pip install -r tools/requirements.txt
python tools/tests/verifier_schema_postgres.py   # PostgreSQL jetable + contrôles
```

### 1.2 Catalogue de données — livré, mesuré

| Indicateur | Valeur mesurée |
|---|---|
| Fiches au total | **115** |
| Fiches publiées | 113 (2 fiches héritées sans localisation restent non publiées) |
| Régions couvertes | **13 / 14** (Matam manquante, voir §2) |
| Fiche avec source et date de collecte | 115 / 115 (100 %) |
| Adresse renseignée | 113 / 115 (98 %) |
| Coordonnées GPS publiées | 16 / 115 (14 %) — toutes issues d'OpenStreetMap, **aucune vérifiée sur place** |
| Téléphone | 52 / 115 (45 %) |
| WhatsApp | 44 / 115 (38 %) |
| Horaires | 4 / 115 (3 %) — non confirmés, donc aucun badge « ouvert maintenant » |
| Services déclarés | 34 / 115 (30 %) |
| Menus avec au moins un prix | 4 / 115 (3 %) — tous « à confirmer » |
| Photos authentiques | **0** — 8 illustrations génériques, toutes signalées comme telles |
| Propriétaire confirmé par une source | **0** — l'application affiche « Propriétaire non renseigné » |

Répartition : Dakar 61, Thiès 14, Saint-Louis 9, Ziguinchor 8, Tambacounda 7,
Diourbel 4, Kaolack 4, Fatick 2, Kaffrine 2, Kolda 1, Louga 1, Kédougou 1,
Sédhiou 1.

Détail complet et limites : `docs/RAPPORT_COUVERTURE.md` (généré).

### 1.3 Chaîne de traitement et d'import — livrée et testée

- `tools/catalogue/importateur.py` : `valider`, `dedoublonner`, `generer`,
  `rapport`, `importer` (CSV/XLSX/JSON), `exporter`.
- Normalisation : téléphones sénégalais (+221), WhatsApp, e-mails, URL, montants
  FCFA, horaires.
- Validation par fiche : erreurs (nom, statut, niveau, région d'une fiche
  publiée, GPS incohérent, contact « confirmé » sans source) et avertissements
  (source ou date manquante, localisation grossière, numéro douteux, doublon de
  contact).
- Détection de doublons : **jamais de fusion automatique**, 3 paires signalées
  aujourd'hui (voir §1.4).
- Génération des trois livrables depuis les mêmes fichiers de collecte
  (JSON applicatif, SQL d'amorçage, rapport de couverture).
- Modèle d'import : `data/templates/modele_import.csv`.

### 1.4 Dédoublonnage SQL/Python — aligné et prouvé

La base et le pipeline utilisent désormais **le même algorithme** (mots
significatifs, Dice/Jaccard, bigrammes, contenance 0,82, pénalité unique de
localisation, seuils 0,62 / 0,50 sur contact partagé). Le vérificateur **compare
les deux listes de paires** et échoue si elles divergent : elles coïncident.

Paires à arbitrer par un humain :
1. `Artisan Boulanger Eric Kayser` ⇄ `Maison Kayser (Éric Kayser)` — score 0,87
   (même quartier) : chaîne de boulangeries, deux adresses distinctes.
2. `Le Pelican` ⇄ `Hôtel-Restaurant Il Pellicano` — score 0,66 (noms proches,
   régions différentes).
3. `La Parilla` ⇄ `Beluga` — score 0,50 : **un même numéro WhatsApp** est
   publié pour les deux enseignes (exploitant commun probable).

### 1.5 Application Flutter — livrée, à vérifier en CI

- `lib/main.dart` n'est plus un fichier de 1 576 lignes : navigation
  Découvrir · Favoris · Commandes · Paramètres, panier accessible par bouton
  flottant.
- Écrans : découverte (recherche + filtres région/type/cuisine/budget/service),
  fiche détaillée, plat, panier, commande (WhatsApp), historique des commandes,
  favoris persistants, carte interactive (OpenStreetMap), contributions (avis,
  signalement, demande de mise à jour, revendication, proposition
  d'établissement), **couverture du recensement** (indicateurs réels),
  paramètres.
- Honnêteté intégrée à l'interface : badge de niveau de vérification sur chaque
  fiche, bandeau « prix non confirmé », mention des illustrations génériques,
  « Propriétaire non renseigné », horaires non affichés comme fiables.
- Corrections d'honnêteté : le bloc « Garantie Hygiène & Propreté » (normes
  HACCP, désinfection) qui affirmait des contrôles jamais réalisés a été
  **supprimé** ; les notes et prix inventés de la version héritée ne sont plus
  présentés comme confirmés.
- Dépendances déclarées : `url_launcher`, `shared_preferences`, `flutter_map`,
  `latlong2`, `supabase_flutter` ; `assets/data/catalogue.json` embarqué (l'app
  fonctionne sans réseau).
- Tests écrits : `test/catalogue_test.dart` (12 tests : sources obligatoires,
  prix confirmés, images génériques signalées, propriétaire jamais déduit,
  recherche et filtres, contrat de données).

### 1.6 Tests et vérifications exécutés

| Vérification | Résultat |
|---|---|
| Schéma + migrations + seed sur PostgreSQL jetable, deux passes | ✔ |
| 6 insertions interdites refusées par les contraintes | ✔ (6/6) |
| Parité de détection des doublons SQL ↔ Python | ✔ (3 paires identiques) |
| Tests du pipeline (`tools/tests/test_catalogue_pipeline.py`) | ✔ 10/10 |
| Tests Flutter (`flutter analyze`, `flutter test`) | **non exécutés ici** : aucun SDK Flutter dans l'environnement — confiés à la CI (§3) |

---

## 2. Ce qui reste à faire (par ordre d'importance)

1. **Contrôle téléphonique de terrain** : aucun numéro n'a été appelé ; c'est la
   seule façon de faire passer des fiches en `verifie` et de remplir horaires,
   menus et services. Rien ne remplace cet appel.
2. **Région de Matam : aucune fiche.** Les sources consultées n'ont renvoyé
   aucun établissement nommé (et l'API Overpass limitait fortement les requêtes
   au-delà de quelques extractions successives). À traiter par contact direct avec les
   établissements (Matam, Ourossogui, Kanel, Ranérou) ou relevé terrain.
3. **GPS vérifiés : 0.** Les 16 coordonnées existantes sont communautaires
   (OpenStreetMap) ; à confirmer avant de les présenter comme fiables.
4. **Photos authentiques : 0.** Aucune photo n'a été publiée faute
   d'autorisation documentée. Il faut une campagne « restaurateur » (accord écrit,
   auteur, date) et le stockage des autorisations.
5. **Menus réels : 4 fiches sur 115.** Les autres affichent « Menu à confirmer
   auprès du restaurant ». À collecter auprès des restaurateurs (photos de carte
   autorisées).
6. **Base communautaire Supabase non connectée** dans cette version : avis,
   signalements et revendications sont conservés **localement** et l'application
   le dit. Il reste à créer le projet Supabase et à fournir
   `SUPABASE_URL` / `SUPABASE_ANON_KEY` à la compilation.
7. **Espace restaurateur** : la revendication est enregistrée, mais l'espace
   d'édition en ligne (menu, prix, horaires, photos) n'est pas encore exposé —
   les politiques RLS sont écrites, l'interface reste à faire.
8. **Tableau de bord administrateur** : les vues existent côté base ; côté
   application, l'écran accessible au public est un **diagnostic en lecture
   seule**. L'interface d'administration (file de travail, arbitrage des
   doublons, traitement des demandes) reste à développer et doit être protégée
   par le rôle `administrateur`.
9. **Commandes intégrées** : volontairement désactivées. Le panier prépare un
   message WhatsApp ; l'architecture distingue déjà les modes de commande
   (direct, téléphone, WhatsApp, site du restaurant, DEKK FOOD, livraison
   restaurant/partenaire, retrait) mais aucun frais, délai ou paiement n'est
   affiché comme confirmé.
10. **Couverture nationale incomplète** : 13 régions sur 14, très inégale
    (Dakar 61 fiches contre 1 en Kédougou, Louga, Kolda et Sédhiou). Le
    recensement est un travail continu, pas un résultat acquis.
11. **Vérifications non exécutables ici** : compilation Flutter (web et mobile)
    et tests associés — à lancer en CI ; le déploiement reste le workflow
    existant `.github/workflows/deploy.yml` (branche `main` uniquement).

---

## 3. Comment vérifier soi-même

```bash
# 1. Données et règles
python3 tools/catalogue/importateur.py valider data/seed/*.json
python3 tools/catalogue/importateur.py dedoublonner data/seed/*.json
python3 tools/catalogue/importateur.py generer data/seed/*.json --dossier . --rapport docs/RAPPORT_COUVERTURE.md

# 2. Tests (pipeline + base PostgreSQL jetable)
pip install -r tools/requirements.txt
python -m pytest

# 3. Application
flutter pub get
flutter analyze
flutter test
flutter run -d chrome        # ou: flutter build web --release
```

---

## 4. Règles que le projet s'interdit (rappel opposable)

- Ne pas inventer de restaurant, de plat, de prix, de promotion ni d'horaire.
- Ne pas présenter une donnée « trouvée en ligne » comme « confirmée ».
- Ne pas afficher de badge « ouvert maintenant » sans horaires fiables.
- Ne pas nommer un propriétaire sans source publique ou autorisation.
- Ne pas publier une photo sans droits documentés ; signaler les illustrations
  génériques.
- Ne pas fusionner automatiquement deux fiches similaires.
- Ne pas publier une donnée personnelle.
- Ne pas contourner les protections techniques des sources.
- Ne pas déclarer le recensement complet tant que la couverture n'est pas
  mesurée et les limites documentées.
