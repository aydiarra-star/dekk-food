# Architecture des données — DEKK FOOD

## 1. Principe directeur

Une **seule source de vérité** alimente trois livrables :

```
data/seed/*.json   (collecte, une fiche = un fichier de provenance)
        │
        ├── tools/catalogue/importateur.py valider    → contrôle qualité (erreurs / avertissements)
        ├── tools/catalogue/importateur.py dedoublonner → doublons suspectés (jamais fusionnés)
        └── tools/catalogue/importateur.py generer    → assets/data/catalogue.json   (application Flutter)
                                                      → supabase/seed/10_etablissements.sql (base)
                                                      → docs/RAPPORT_COUVERTURE.md  (mesure de couverture)
```

La base PostgreSQL/Supabase et l'application ne peuvent donc pas diverger : elles
sont régénérées depuis les mêmes fichiers, versionnés dans le dépôt.

## 2. Modèle relationnel (schéma `public`)

### Référentiel géographique
- `regions` (14), `departements` (46), `communes`, `quartiers`
- Chaque établissement publié est rattaché à une région
  (`restaurants_publication_localisation_check`) : impossible de publier une
  fiche hors du territoire.

### Catalogue
- `restaurants` — table centrale héritée du schéma initial, **étendue** (environ
  40 colonnes) : identité (`numero_fiche`, `slug`, `nom_officiel`), statut
  d'exploitation (`statut`), niveau de vérification (`niveau_verification`),
  adresse et géolocalisation (`gps_verifie`), contacts professionnels, fourchette
  de prix, services, exploitation déclarée, source principale, visibilité.
- `etablissement_sources` — traçabilité : qui a fourni quoi, quand, avec quel
  niveau de confiance (contrainte d'unicité par fiche + source + URL).
- `etablissement_contacts`, `horaires`, `horaires_exceptionnels`,
  `etablissement_services`, `zones_livraison`, `images`.
- `menus` → `menu_sections` → `plats` → `plat_images`,
  `allergenes`/`regimes` (tables de liaison).
- `entreprises`, `gestionnaires`, `etablissement_proprietaires` — propriété et
  gestion, **uniquement documentées** (une ligne confirmée exige une source).
- `promotions` (menus du jour, formules, offres datées).
- `avis`, `signalements`, `demandes_correction`, `revendications` — contributions
  des visiteurs et procédures de contrôle.
- `import_lots`, `import_lignes`, `doublons_suspects`, `journal_modifications`,
  `utilisateurs_admin` — administration, import, audit.

### Invariants garantis par la base (vérifiés automatiquement)

| Invariant | Contrainte |
|---|---|
| Un prix confirmé a une source | `plats_prix_source_check` |
| Un horaire confirmé a une source | `horaires_source_check` |
| Un menu confirmé a une source | `menus_source_check` |
| Une zone de livraison confirmée a une source | `zones_livraison_source_check` |
| Un propriétaire confirmé a une source | `entreprises_source_obligatoire` |
| Une image générique est signalée comme telle | `images_generique_coherence` |
| Une fiche publiée est localisée | `restaurants_publication_localisation_check` |
| Un compte « restaurateur » est rattaché à un établissement | `utilisateurs_admin_restaurateur_check` |
| Le niveau de vérification n'est pas modifiable par un restaurateur | trigger + RLS |
| Aucune fusion automatique de doublons | `doublons_suspects` = suggestion |

Ces règles sont testées pour de vrai : `tools/tests/verifier_schema_postgres.py`
démarre un PostgreSQL jetable, applique le schéma et le seed, puis **vérifie que
six insertions interdites sont refusées**.

## 3. Détection des doublons (double implémentation volontaire)

Le même algorithme existe en Python (`tools/catalogue/dedoublonnage.py`) et en
SQL (`public.similarite_noms`, `public.detecter_doublons`) :

1. `cle_nom` : minuscules, accents et ponctuation retirés.
2. `cle_nom_significative` : mots significatifs (liste de mots génériques
   identique dans les deux langages : restaurant, chez, hôtel, maison…).
3. Score = meilleur de : Dice des mots, Jaccard des mots, ressemblance des
   identifiants (bigrammes), contenance plafonnée à 0,82.
4. Indices supplémentaires : site web, WhatsApp, téléphone, proximité GPS
   (< 150 m), adresse précise identique, quartier identique.
5. Pénalité unique : région divergente (−0,20), sinon commune divergente (−0,15).
6. Deux seuils : 0,62 sur le nom ; 0,50 dès qu'un contact professionnel est
   partagé (signal indépendant du nom).

Le vérificateur **compare les deux listes de paires** et échoue si elles
diffèrent : au 2026-10-13, les trois mêmes paires sont proposées par les deux
moteurs. Aucune fusion n'est jamais automatique.

## 4. Complétude et file de travail

- `v_qualite_catalogue` : totaux, fiches publiées, adresses confirmées, fiches
  jamais vérifiées, fiches obsolètes.
- `v_couverture_par_region`, `v_couverture_par_ville`, `v_couverture_par_categorie`.
- `v_file_travail` : fiches les plus incomplètes, priorisées.
- `v_doublons_a_examiner` : paires en attente d'arbitrage humain.
- `v_etablissements_publics`, `v_plats_publics` : lecture publique filtrée.

L'application embarque une version locale de ces indicateurs (écran
« Couverture du recensement ») calculée sur le catalogue publié, afin qu'un
utilisateur puisse constater les manques sans accès à la base.

## 5. Côté application Flutter

- `lib/models/catalogue.dart` — modèles alignés sur le JSON généré :
  `Etablissement`, `MenuCarte`, `Plat`, `ImageEtablissement` (avec
  `mentionDroits`), `HoraireJour`, `ServiceEtablissement`, `SourceInfo`,
  `Exploitation`, `FiltresCatalogue`, `Avis`, `Demande`.
- `lib/data/catalogue_repository.dart` — chargement du JSON embarqué,
  recherche/filtres, favoris (SharedPreferences), contributions locales.
  Supabase est **optionnel** : activé uniquement si
  `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` sont
  fournis. Sans configuration, l'application ne prétend jamais transmettre quoi
  que ce soit (« la base communautaire n'est pas connectée »).
- Aucune clé secrète n'est présente dans le code : seules des variables de
  compilation sont lues, et la clé « anon » de Supabase est publique par
  conception.

## 6. Import de données (CSV / XLSX / JSON)

1. Modèle : `data/templates/modele_import.csv`.
2. Commande : `python3 tools/catalogue/importateur.py importer <fichier> --dossier .`
   → validation, normalisation (téléphones sénégalais, URL, horaires, prix),
   détection des doublons, contrôle des sources, journal de lot.
3. Chaque lot produit un rapport : lignes ajoutées, mises à jour, rejetées,
   doublons et éléments à vérifier (rapport non destructif : une correction crée
   une ligne d'historique, elle n'écrase pas).
