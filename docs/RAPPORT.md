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
| Fiches au total | **185** |
| Fiches publiées | 183 en base sur 185 — les 2 fiches héritées sans localisation (Diamniadio Express Diner, La Halte AIBD) restent non publiées côté base |
| Régions couvertes | **14 / 14** — Matam est représentée depuis le 13/10/2026 (1 fiche relevée sur OpenStreetMap à Ourossogui), mais la profondeur reste très inégale (voir §2) |
| Fiche avec source et date de collecte | 185 / 185 (100 %) |
| Adresse renseignée | 125 / 185 (68 %) |
| Coordonnées GPS publiées | 87 / 185 (47 %) — toutes issues d'OpenStreetMap, **aucune vérifiée sur place** |
| Téléphone | 63 / 185 (34 %) |
| WhatsApp | 44 / 185 (24 %) |
| Horaires | 4 / 185 (2 %) — non confirmés, donc aucun badge « ouvert maintenant » |
| Services déclarés | 34 / 185 (18 %) |
| Menus avec au moins un prix | 4 / 185 (2 %) — tous « à confirmer » |
| Photos authentiques | **0** — 8 illustrations génériques, toutes signalées comme telles |
| Propriétaire confirmé par une source | **0** — l'application affiche « Propriétaire non renseigné » |

Répartition : Dakar 61, Ziguinchor 33, Thiès 28, Kaolack 15, Diourbel 13, Saint-Louis 9, Louga 7, Tambacounda 7, Fatick 4, Kolda 3, Kaffrine 2, Matam 1, Kédougou 1, Sédhiou 1, horaires 181, menu 181, telephone 122, gps 98, adresse 60.
Ziguinchor 8, Tambacounda 7, Louga 5, Kolda 3, Fatick 2, Kaffrine 2, Matam 1,
Kédougou 1, Sédhiou 1.

**Arbitrage d'un doublon inter-sources (13/10/2026).** Le dédoublonnage a signalé
« Dibiterie Saf Sap » (Touba) présent à la fois dans l'annuaire Senefinder et dans
OpenStreetMap, avec le même numéro de téléphone. Après examen humain, les deux
fiches ont été réunies en une seule (DF-DB-0003) enrichie des coordonnées GPS
relevées sur OpenStreetMap, et la fiche en double a été retirée. Un contrôle
bloquant a été ajouté : deux fiches ne peuvent plus partager le même slug, sinon
la génération du script d'amorçage est refusée (auparavant, la seconde fiche
était silencieusement écrasée en base).

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
| Schéma + migrations (0001 → 0006) + seed sur PostgreSQL jetable, deux passes | ✔ |
| Insertions interdites refusées par les contraintes | ✔ (11/11) |
| Parité de détection des doublons SQL ↔ Python | ✔ (10 paires identiques) |
| Cloisonnement par rôle (anon / administrateur / restaurateur / compte inconnu) | ✔ (90 vérifications, 0 échec, déterministe sur 3 exécutions) |
| Tests du pipeline (`tools/tests/test_catalogue_pipeline.py`) | ✔ 19/19 |
| Tests Flutter (`flutter analyze`, `flutter test`) | **non exécutés ici** : aucun SDK Flutter dans l'environnement — confiés à la CI (§3) |
| Tests de rôles contre la base Supabase de production | **non exécutés** : aucun accès au projet distant depuis cet environnement ; le contrôle a été mené sur un PostgreSQL local appliquant les migrations réelles |

---

## 2. Ce qui reste à faire (par ordre d'importance)

1. **Contrôle téléphonique de terrain** : aucun numéro n'a été appelé ; c'est la
   seule façon de faire passer des fiches en `verifie` et de remplir horaires,
   menus et services. Rien ne remplace cet appel.
2. **Région de Matam : 1 fiche.** Le relevé OpenStreetMap du 13/10/2026 a
   identifié « Samassa » à Ourossogui, ce qui met fin à l'absence totale de fiche,
   mais aucune source consultée ne permet encore de couvrir Matam, Kanel ou
   Ranérou. À traiter par contact direct avec les établissements ou relevé terrain.
3. **GPS vérifiés : 0.** Les 87 coordonnées existantes sont communautaires
   (OpenStreetMap) ; à confirmer avant de les présenter comme fiables.
4. **Photos authentiques : 0.** Aucune photo n'a été publiée faute
   d'autorisation documentée. Il faut une campagne « restaurateur » (accord écrit,
   auteur, date) et le stockage des autorisations.
5. **Menus réels : 4 fiches sur 185.** Les autres affichent « Menu à confirmer
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
10. **Couverture nationale incomplète** : les 14 régions sont représentées,
    mais la profondeur est très inégale (Dakar 61 fiches contre 1 en Matam,
    Kédougou et Sédhiou). Aucune source ne garantit l'exhaustivité : le recensement
    est un travail continu, pas un résultat acquis.
11. **Vérifications non exécutables ici** : compilation Flutter (web et mobile)
    et tests associés — à lancer en CI ; le déploiement reste le workflow
    existant `.github/workflows/deploy.yml` (branche `main` uniquement).
12. **Risques résiduels identifiés pendant l'audit du 14/10** (ni corrigés, ni
    masqués) :
    - `lib/services/supabase_service.dart` et `lib/models/restaurant.dart` sont du
      code mort qui interroge un schéma abandonné (`restaurants.is_active`,
      `menu_items`). Ils ne sont importés nulle part et ne peuvent donc rien
      divulguer aujourd'hui, mais ils induisent en erreur : à supprimer ou à
      réécrire sur le schéma actuel.
    - Les fiches non publiées restent présentes, **réduites**, dans le catalogue
      distribué (identité, motif, provenance) pour que la conservation et les
      compteurs restent démontrables. Une séparation totale demande un fichier
      interne distinct : décision de conception, pas correctif de sécurité.
    - Les positions restent indicatives : aucune n'est confirmée par une
      vérification recevable, et le filtre « GPS vérifié » doit donc rester vide.
    - Le cloisonnement a été prouvé sur PostgreSQL local avec les migrations réelles
      (rôles `anon` / `authenticated`), pas contre le projet Supabase distant.

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

# 4. Sécurité des parcours publics (rôles réels, PostgreSQL jetable)
python3 tools/tests/verifier_schema_postgres.py   # 90 vérifications, doit finir par 0 échec

# 5. Conservation et distribution
python3 - <<'EOF'
import json
catalogue = json.load(open('assets/data/catalogue.json'))
non_publiees = [f for f in catalogue['etablissements'] if not f['est_publication_visible']]
print(len(catalogue['etablissements']), 'fiches conservées,', len(non_publiees), 'non publiées')
for fiche in non_publiees:
    assert fiche['adresse'] is None and fiche['telephone'] is None, fiche['slug']
    assert fiche['motif_non_publication'] and fiche['sources']
print('aucune donnée pratique distribuée pour les fiches non publiées : OK')
EOF
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

12. **Divergence base/application : RÉSOLUE (règle de publication explicite).**
    Le catalogue embarqué expose désormais `est_publication_visible` et
    `motif_non_publication`, calculés par une règle unique
    (`tools/catalogue/modele.py`, constante `REGLE_PUBLICATION`) appliquée au
    catalogue **et** au script d'amorçage SQL. La règle est publiée dans le
    catalogue (`couverture.publication.regle`) et vérifiée par le harnais
    PostgreSQL : le catalogue et la base déclarent exactement les mêmes fiches non
    publiées. Les deux fiches héritées (Diamniadio Express Diner, La Halte AIBD)
    restent présentes partout — **aucune donnée n'a été supprimée** —, elles ne sont
    simplement pas publiées, avec un motif affiché à l'écran si on les ouvre.
13. **Enrichissement : plan calculé, pas d'estimation.** `docs/PLAN_ENRICHISSEMENT.md`
    hiérarchise les 185 fiches : 105 sont joignables par téléphone/WhatsApp (P1), 80
    n'ont aucun contact public (P3). Le fichier
    `data/exports/file_de_travail_verification.csv` sert de feuille de tournée.
14. **Validation humaine : 0 fiche validée.** Aucune fiche n'est passée par le
    contrôle (`public.valider_fiche_par_controle`), qui exige une personne identifiée
    et une preuve. « Publiée » ne veut donc jamais dire « vérifiée » : l'interface et
    la base distinguent désormais les deux notions, et un test le vérifie.
15. **Contributions restaurateurs : procédure écrite, formulaire à construire.**
    La procédure de revendication/correction est formalisée dans `docs/SOURCES.md`
    (preuves acceptées, délais, contrôle avant publication). La base impose déjà
    qu'une revendication ne vaut jamais vérification. Le formulaire Web et l'écran
    d'administration restent à développer (voir §2.7 et §2.8).

## 5. Audit du 14/10/2026 — fiabilité des données et sécurité des parcours publics

Audit ciblé (aucune refonte) sur trois défauts de niveau P0. Les trois ont été
reproduits **avant** correction, puis revérifiés après.

### 5.1 P0 — GPS : la carte et le filtre présentaient des positions non vérifiées comme vérifiées

- **Constat initial** (`lib/screens/carte_screen.dart`, `lib/models/catalogue.dart`) :
  le filtre « Avec GPS vérifié » testait la seule présence de coordonnées ; la carte
  regroupait les fiches sur `aDesCoordonnees` et son bandeau annonçait des fiches
  « géolocalisées » / « sans coordonnées vérifiées ». Mesure sur le catalogue :
  **87 fiches ont des coordonnées, 0 est vérifiée** — le filtre retournait donc
  87 résultats en promettant des positions vérifiées.
- **Corrections** : une coordonnée n'est exploitable que si elle est complète,
  numérique et dans l'emprise du Sénégal (mêmes bornes que le pipeline Python) ;
  `positionConfirmee` exige `gps_verifie` en plus ; le filtre « GPS vérifié » exige
  désormais explicitement une position confirmée et ne retient donc **aucune** fiche
  aujourd'hui ; la carte distingue pictogramme, couleur et légende entre position
  confirmée et position indicative, et son bandeau chiffre les deux ; la fiche
  affiche « Position NON confirmée : coordonnées indicatives, à valider sur place » ;
  le bouton d'itinéraire s'intitule « Itinéraire (position indicative) » tant que la
  position n'est pas confirmée. Les coordonnées sources ne sont pas modifiées et
  aucune position estimée ne peut devenir confirmée dans l'application.
- **Tests** : coordonnées présentes + confirmées, présentes non confirmées, absentes,
  invalides (hors emprise, NaN, infinies, incomplètes), drapeau « vérifié » sur des
  coordonnées aberrantes, comportement exact du filtre, et
  « une position n'est déclarée confirmée qu'avec une vérification documentée ».

### 5.2 P0 — Publication : une fiche non publiée restait atteignable, et ses données étaient publiées hors application

- **Constats** : l'écran des favoris listait le catalogue complet (fiches non
  publiées incluses) et ouvrait leur fiche détaillée ; l'écran de diagnostic
  (accessible depuis les paramètres) ouvrait toute fiche de la file de travail ; et
  surtout `assets/data/catalogue.json`, **embarqué dans l'application et publié en
  ligne**, contenait l'adresse, le téléphone et les services des deux fiches non
  publiées. Une fiche non publiée n'était donc pas seulement atteignable : ses
  coordonnées étaient diffusées.
- **Corrections** : règle unique appliquée — non publiée = conservée, jamais
  présentée comme une fiche publique. L'écran de détail intercepte toute fiche non
  publiée (recherche, carte, favoris, diagnostic, ouverture directe) et affiche un
  avis interne : motif, mention de conservation, et **aucune** donnée pratique. Les
  favoris sont séparés en fiches publiées (listées), fiches non publiées (comptées,
  non listées) et favoris orphelins (signalés sans plantage). La génération retire
  désormais les données pratiques des fiches non publiées avant distribution
  (`reduire_fiche_non_publiee`), en conservant identité, motif et provenance ; les
  sources du dépôt et le script SQL d'amorçage gardent l'intégralité. Les compteurs
  d'application (`qualiteDistribuee`) portent sur les fiches réellement diffusées et
  l'écran de diagnostic l'explique.
- **Conservation démontrée** : 185 fiches avant comme après ; 183 publiées / 2 non
  publiées, inchangées ; les 183 fiches publiées sont identiques au caractère près
  dans le catalogue distribué ; les 2 fiches non publiées gardent nom, commune,
  motif, provenance et une ligne « Propriétaire non renseigné ».
- **Tests** : recherche par nom, identifiant et slug (aucune remontée), listes et
  compteurs publics, favoris (publiés / non publiés / orphelins), rendu de l'écran de
  détail en accès direct (aucune donnée pratique affichée), et contrôle de
  non-régression du catalogue distribué.
- **Limite connue, à trancher si le besoin devient une exigence stricte** : les
  fiches non publiées restent présentes (réduites) dans le catalogue distribué pour
  la traçabilité et les compteurs. Une séparation totale impliquerait un fichier
  interne distinct non embarqué, ce qui changerait le pipeline de génération.

### 5.3 P0 — Sécurité : les tables rattachées laissaient lire les données des fiches non publiées

- **Constat** (migration `0003`) : `restaurants` était protégée, mais les tables
  filles (contacts, menus, plats, images, horaires, zones de livraison, services…)
  conservaient une policy `using (true)`. Démonstration en rôle `anon` sur une fiche
  non publiée : le contact `+221781112233` était lisible avant correction.
- **Défaut supplémentaire découvert pendant l'audit** : les policies de 0003
  interrogeaient `utilisateurs_admin`, dont les policies appellent
  `est_administrateur()` → `role_courant()` → `utilisateurs_admin` ; PostgreSQL
  refusait la requête par récursion infinie. Dès qu'un compte administrateur ou
  restaurateur existait, **aucune** requête d'un rôle non-superutilisateur sur
  `restaurants` n'aboutissait : les accès « administrateur » et « restaurateur »
  étaient inutilisables, et la garde « un restaurateur ne peut pas s'attribuer le
  niveau vérifié » comparait la ligne à elle-même. Le défaut était invisible tant que
  la table des comptes restait vide.
- **Corrections** : `0005_cloisonnement_public.sql` fait dépendre la lecture publique
  de chaque table rattachée de la visibilité de sa fiche parente (donc des policies
  du parent), ferme la table héritée `menu_items` (restée sans RLS) et ajoute la vue
  de contrôle `v_cloisonnement_public`. `0006_acces_admin_restaurateur.sql` passe les
  fonctions d'identité en `security definer`, introduit
  `etablissement_du_restaurateur()` et rend effectif le refus d'auto-attribution du
  niveau vérifié, avec la vue `v_acces_comptes`.
- **Résultats mesurés** (rôles `anon`, `authenticated` administrateur, restaurateur,
  compte authentifié inconnu) : visiteur anonyme `0` ligne pour toute table d'une
  fiche non publiée ; administration `= total` (conservation intacte) ; restaurateur
  `= total` pour sa seule fiche et `0` pour celle d'un tiers ; journaux et notes de
  vérification inaccessibles ; fiches publiées toujours lisibles (aucun excès de
  zèle) ; aucune politique `using (true)` restante sur une table rattachée.
- **Tests** : `tools/tests/verifier_schema_postgres.py` exécute ces contrôles sur une
  instance PostgreSQL jetable — 90 vérifications, vertes et déterministes.
  Les rôles ne peuvent pas être testés contre la base Supabase distante (aucun accès
  au projet en production depuis cet environnement) : le contrôle a été mené sur un
  PostgreSQL local appliquant les migrations réelles.

### 5.3 bis — Correctif complémentaire (migration `0007`) : vues internes, rôles et fonctions `SECURITY DEFINER`

- **Constat reproduit sur `6a09d16`** : `v_acces_comptes`, `v_cloisonnement_public`,
  `v_publication_catalogue` et `v_fiches_a_valider` avaient reçu `GRANT SELECT ... TO authenticated`
  sans `security_invoker = true`. Exécutées sous leur propriétaire (`postgres`), elles
  exposaient à tout compte `authenticated` (ordinaire, lecteur, inactif ou restaurateur) les
  emails/rôles de `utilisateurs_admin` et les identifiants/noms/motifs des 2 fiches non
  publiées. De plus, `public.detecter_doublons()` (`SECURITY DEFINER`) était exécutable par
  `anon` et `authenticated` sans `search_path` figé, et la garde `WITH CHECK` sur
  `restaurants` lisait la nouvelle ligne au lieu de `OLD`.
- **Corrections (`0007_securite_vues_et_fonctions.sql`)** :
  - création des rôles PostgreSQL `administrateur` et `restaurateur` ;
  - activation de `security_invoker = true, security_barrier = true` sur les 12 vues ;
  - révocation de `SELECT` pour `PUBLIC, anon, authenticated, restaurateur` sur les 10 vues
    internes (`v_acces_comptes`, `v_cloisonnement_public`, `v_publication_catalogue`,
    `v_fiches_a_valider`, `v_file_travail`, `v_doublons_a_examiner`, `v_qualite_catalogue`,
    `v_couverture_par_region`, `v_couverture_par_ville`, `v_couverture_par_categorie`),
    accordé uniquement à `administrateur, service_role`, avec garde active
    `public.exiger_acces_administration()` (`SQLSTATE 42501`) ;
  - déclencheur `BEFORE UPDATE` `trg_restaurants_controle_modification` bloquant toute
    modification de `niveau_verification`, `est_publication_visible`,
    `motif_non_publication`, `statut_validation` ou `commentaire_verification` par un non-admin ;
  - `search_path = public, pg_temp` sur les 17 fonctions du schéma `public`, et révocation
    de `EXECUTE` sur `detecter_doublons`, `valider_fiche_par_controle`, `devalider_fiche`
    et `exiger_acces_administration` pour `PUBLIC, anon, authenticated, restaurateur`.
- **Vérifications ajoutées au harnais PostgreSQL et à la CI** : refus d'accès prouvé sur
  chacune des 10 vues internes et des fonctions d'administration sous `anon`,
  `authenticated` sans compte, compte authentifié ordinaire, compte `lecteur`, compte
  `admin` inactif (y compris sous le rôle `administrateur`), compte `restaurateur` inactif,
  `restaurateur` de la fiche 1 et `restaurateur` rattaché à une autre fiche ; accès
  administrateur actif et parcours publics (`v_etablissements_publics`, `v_plats_publics`)
  préservés.

### 5.4 Ce qui n'a pas été fait, et pourquoi

- Aucune fusion de la pull request, aucun déploiement, aucune modification de `main`.
- Aucune fiche supprimée, aucune donnée réelle remplacée, aucun niveau de vérification
  attribué : `0` fiche validée avant comme après, aucun propriétaire inventé,
  aucune photo ajoutée.
- Les coordonnées sources n'ont pas été modifiées ; les bornes géographiques servent
  au contrôle, pas à la correction.
- Les positions restent indicatives : seule une vérification recevable pourra
  confirmer une position, et l'application le dit à chaque écran concerné.
