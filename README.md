# DEKK FOOD — catalogue national des établissements du Sénégal

Application Flutter + base PostgreSQL/Supabase recensant les restaurants,
fast-foods, gargotes, dibiteries, pizzerias, cafés, pâtisseries et traiteurs du
Sénégal, **avec la provenance de chaque information**.

> Ce catalogue est **progressif et incomplet par nature** : chaque fiche indique
> son niveau de vérification (« Vérifié », « Partiellement vérifié »,
> « À confirmer ») et sa date de collecte. Aucun plat, prix, horaire ou
> propriétaire n'est inventé. Voir `docs/SOURCES.md` et `docs/RAPPORT.md`.

## Contenu du dépôt

```
lib/                     application Flutter (écrans, modèles, état, widgets)
assets/data/catalogue.json   catalogue embarqué (généré, 183 fiches)
data/seed/               fichiers de collecte (source de vérité)
data/templates/          modèle d'import CSV
docs/                    audit, sources, architecture, rapports de couverture
supabase/                schéma, migrations 0001→0003, seeds (référentiel + catalogue)
tools/catalogue/         pipeline : validation, normalisation, dédoublonnage, génération, import
tools/tests/             tests du pipeline et vérification du schéma (PostgreSQL jetable)
test/                    tests Flutter du catalogue
```

## Démarrage

```bash
flutter pub get
flutter run -d chrome          # ou : flutter run -d android
```

Base communautaire (optionnelle) — l'application fonctionne sans elle, en
lecture seule depuis le catalogue embarqué :

```bash
flutter run --dart-define=SUPABASE_URL=https://<projet>.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=<clé publique anon>
```

Aucune clé secrète ne doit être placée dans le code ni dans le dépôt.

## Pipeline de données

```bash
python3 -m pip install -r tools/requirements.txt

# 1. Contrôler les fichiers de collecte
python3 tools/catalogue/importateur.py valider data/seed/*.json

# 2. Chercher les doublons (jamais fusionnés automatiquement)
python3 tools/catalogue/importateur.py dedoublonner data/seed/*.json

# 3. Régénérer l'application, le seed SQL et le rapport de couverture
python3 tools/catalogue/importateur.py generer data/seed/*.json \
        --dossier . --rapport docs/RAPPORT_COUVERTURE.md

# 4. Import d'un lot CSV/XLSX/JSON
python3 tools/catalogue/importateur.py importer <fichier> --dossier .

# 5. Tests (pipeline + base PostgreSQL jetable)
python3 -m pytest
```

## Base de données

```bash
psql "$DATABASE_URL" -f supabase/schema.sql
for f in supabase/migrations/*.sql; do psql "$DATABASE_URL" -f "$f"; done
psql "$DATABASE_URL" -f supabase/seed/00_referentiel.sql
psql "$DATABASE_URL" -f supabase/seed/10_etablissements.sql
```

Les migrations sont idempotentes : les rejouer ne duplique rien. La base refuse
les données non conformes (prix confirmé sans source, image générique présentée
comme authentique, fiche publiée sans région, compte restaurateur non rattaché).

## Vérifications automatiques

- `.github/workflows/ci.yml` : cohérence des données, tests Python, schéma sur
  PostgreSQL jetable, `flutter analyze`, `flutter test`, compilation web.
- `.github/workflows/deploy.yml` : seul chemin de déploiement (GitHub Pages,
  branche `main`) — inchangé.

## Documentation

| Document | Contenu |
|---|---|
| `docs/RAPPORT.md` | ce qui est livré, ce qui reste, chiffres mesurés |
| `docs/RAPPORT_COUVERTURE.md` | couverture par région et taux de complétude (généré) |
| `docs/SOURCES.md` | sources, droits, politique de vérification, revendications |
| `docs/ARCHITECTURE_DONNEES.md` | modèle de données, invariants, doublons, import |
| `docs/AUDIT.md` | audit de l'application et du schéma hérités |
