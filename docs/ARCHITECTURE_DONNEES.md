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

## Règle de publication (une seule définition)

`tools/catalogue/modele.py` porte la constante `REGLE_PUBLICATION` et la fonction
`decider_publication()` : c'est **le seul endroit** où la publication est décidée.
`generation.py` s'en sert pour le catalogue embarqué **et** pour le script
d'amorçage SQL ; la base la complète par des contraintes (`0004`) ; l'application la
lit (`est_publication_visible`, `motif_non_publication`) au lieu de la réinterpréter.

Conditions cumulatives : région renseignée, au moins une source documentée, niveau
de vérification différent de « information indisponible », aucune erreur de
validation. Le drapeau du fichier de collecte exprime l'**intention** : la règle ne
peut que la restreindre. Une fiche non publiée est **conservée partout** (dépôt,
catalogue, base) avec son motif — rien n'est supprimé.

| Niveau | Qui décide | Où |
|---|---|---|
| Intention de publier | Fichier de collecte (`est_publication_visible`) | `data/seed/*.json` |
| Décision de publier | `decider_publication()` | `tools/catalogue/modele.py` |
| Refus impossibles à contourner | Contraintes SQL | `supabase/migrations/0004_*.sql` |
| Affichage | `estPublicationVisible` + `publicationLibelle` | `lib/models/catalogue.dart`, `lib/screens/fiche_screen.dart` |

## Provenance, validation et droits d'image (migration 0004)

- `restaurants.motif_non_publication` : toute fiche non publiée explique pourquoi.
- `restaurants.statut_validation` (`non_validee` par défaut), `validation_par`,
  `validation_le` : « publiée » n'est pas « vérifiée ».
- `public.valider_fiche_par_controle(uuid, niveau, preuves, commentaire)` : seul
  chemin pour attribuer un niveau de vérification. Exige un administrateur identifié
  **et** une preuve ; journalise qui, quand, sur quoi.
- `public.devalider_fiche(uuid, motif)` : retire un badge de façon motivée
  (fermeture, erreur signalée, demande de retrait).
- `images.autorisation_reference`, `images.autorisation_obtenue_le` : une photo
  présentée comme authentique doit avoir auteur, licence ou autorisation.
- `controler_revendication()` : une revendication ne peut pas devenir « vérifiée »
  sans vérificateur identifié ; un rejet doit être motivé.
- Vues `v_publication_catalogue` et `v_fiches_a_valider` (administration seulement).

## Plan d'enrichissement

`tools/catalogue/plan_enrichissement.py` produit `docs/PLAN_ENRICHISSEMENT.md` et
`data/exports/file_de_travail_verification.csv` : priorité 1 (contact direct
possible), 2 (contact indirect), 3 (relevé terrain), les régions les moins couvertes
d'abord. Aucune estimation : tout est calculé sur les fiches réellement collectées.

## Cloisonnement public des données rattachées (migration 0005)

La migration 0003 protégeait `restaurants` mais laissait les tables FILLES en
`for select ... using (true)`. Un visiteur anonyme pouvait donc lire le téléphone,
l'adresse, les contacts, les menus, les plats, les images ou les horaires d'une
fiche **non publiée** en interrogeant directement la table associée.

- Démonstration (outil `tools/tests/verifier_schema_postgres.py`, instance
  PostgreSQL jetable) : avant 0005, `select * from contacts where restaurant_id = <fiche non publiée>`
  renvoyait bien le contact (+221 78 111 22 33 de `diamniadio-express-diner`) en rôle `anon`.
- Après 0005 : chaque policy de lecture d'une table fille s'appuie sur sa fiche
  parente (`exists (select 1 from restaurants r where r.id = <table>.restaurant_id)`),
  donc sur la policy du parent. Résultat mesuré :
  - visiteur anonyme : **0** ligne d'une fiche non publiée, et les fiches publiées
    restent intégralement lisibles (contrôle de non-blocage) ;
  - administration : accès complet conservé ;
  - restaurateur : accès à **sa** fiche (publiée ou non) et aucune autre fiche non
    publiée, aucun journal, aucune note de vérification ;
  - utilisateur authentifié quelconque : mêmes droits que le public.
- `menu_items`, table héritée restée sans RLS (donc lisible par `anon`), est
  désormais fermée à l'administration uniquement.
- Vue `v_cloisonnement_public` (administration) : par fiche, le nombre de données
  rattachées, pour prouver que rien n'a été supprimé pour cloisonner.

## Accès administrateur et restaurateur (migration 0006)

Défaut mesuré : les policies de 0003 interrogeaient `utilisateurs_admin`, dont les
policies appellent `est_administrateur()` → `role_courant()` → `utilisateurs_admin`.
PostgreSQL refusait alors la requête (`infinite recursion detected in policy for
relation "restaurants"`) : dès qu'un compte d'administration ou de restaurateur
existait, **aucune** requête d'un rôle non-superutilisateur sur `restaurants` ni sur
les tables rattachées n'aboutissait. Les accès n'étaient pas simplement restreints,
ils étaient inutilisables. Le défaut restait invisible tant que la table des
comptes était vide.

- `role_courant()`, `est_administrateur()` et `etablissement_du_restaurateur()`
  passent en `security definer` : elles lisent `utilisateurs_admin` sans repasser
  par ses policies (fin de la récursion) et ne renvoient que des informations
  relatives à l'appelant.
- La contrainte « un restaurateur ne peut pas s'attribuer le niveau vérifié » est
  rendue effective : la sous-requête comparait la ligne à elle-même (`r.id = id`),
  la comparaison porte désormais explicitement sur la ligne contrôlée.
- Vue `v_acces_comptes` (administration) : qui accède à quoi, pour vérifier qu'aucun
  compte inactif ne conserve d'accès.

## Durcissement des vues internes et des fonctions SECURITY DEFINER (migration 0007)

Constat complémentaire sur le commit `6a09d16` :
1. `v_publication_catalogue`, `v_fiches_a_valider` (`0004`), `v_cloisonnement_public` (`0005`)
   et `v_acces_comptes` (`0006`) recevaient `GRANT SELECT ... TO authenticated` et ne
   définissaient pas `security_invoker = true`. En PostgreSQL, une vue s'exécute par défaut
   sous les droits de son propriétaire (`postgres`, qui contourne la RLS) : un compte
   simplement authentifié (ou un restaurateur, ou un compte inactif) pouvait lire les emails
   et rôles de `v_acces_comptes` ainsi que les identifiants, noms, motifs de non-publication
   et compteurs des fiches non publiées dans `v_cloisonnement_public` et
   `v_publication_catalogue`.
2. Les vues créées en `0003` (`v_couverture_par_region`, `v_couverture_par_ville`,
   `v_couverture_par_categorie`, `v_qualite_catalogue`, `v_file_travail`,
   `v_doublons_a_examiner`, `v_etablissements_publics`, `v_plats_publics`) n'avaient ni
   `security_invoker = true`, ni `REVOKE` explicite.
3. En PostgreSQL, une sous-requête dans la clause `WITH CHECK` d'une politique `UPDATE` voit
   déjà la nouvelle ligne : la protection des colonnes de vérification et de publication
   exige un déclencheur `BEFORE UPDATE` comparant `OLD` et `NEW`.
4. Les fonctions `SECURITY DEFINER` `detecter_doublons` et `journaliser` n'avaient pas de
   `search_path` figé et `detecter_doublons` restait exécutable par `PUBLIC` / `anon`.

Corrections apportées (`0007_securite_vues_et_fonctions.sql`) :
- Compatibilité Supabase Auth / PostgREST (sans `service_role` côté client) : sous
  Supabase, un administrateur réel connecté reçoit un JWT de rôle PostgreSQL
  `authenticated` et d'identifiant `sub` (`auth.uid()`). `public.utilisateur_courant()`
  lit dans l'ordre `auth.uid()`, les claims PostgREST (`request.jwt.claim.sub` /
  `request.jwt.claims->>'sub'`) et `dekkfood.utilisateur_id`.
- Rôles PostgreSQL dédiés `administrateur` et `restaurateur` (héritant de `authenticated`
  pour les politiques RLS des tables).
- `security_invoker = true` et `security_barrier = true` activés sur les **12 vues** du
  schéma `public`.
- `REVOKE ALL ... FROM PUBLIC, anon, restaurateur` et attribution du seul privilège
  `SELECT` (aucun `INSERT/UPDATE/DELETE`) à `authenticated, administrateur, service_role`
  sur les **10 vues internes** (`v_acces_comptes`, `v_cloisonnement_public`,
  `v_publication_catalogue`, `v_fiches_a_valider`, `v_file_travail`,
  `v_doublons_a_examiner`, `v_qualite_catalogue`, `v_couverture_par_region`,
  `v_couverture_par_ville`, `v_couverture_par_categorie`), doublés d'une garde
  bloquante `WHERE public.exiger_acces_administration()` compilée par PostgreSQL en
  `One-Time Filter` avant tout parcours de table : tout appel par un compte
  `authenticated` non administrateur actif (ordinaire, `lecteur`, `admin` inactif ou
  `restaurateur`) lève immédiatement `SQLSTATE 42501` (`insufficient_privilege`), tandis
  qu'un administrateur actif (`role in ('admin', 'editeur')` et `actif = true` dans
  `public.utilisateurs_admin`) est autorisé sous `SET LOCAL ROLE authenticated` (mode
  PostgREST standard) comme sous `SET ROLE administrateur`.
- `v_etablissements_publics` et `v_plats_publics` réservées en lecture (`SELECT`) à `anon`,
  `authenticated`, `restaurateur`, `administrateur` et `service_role` avec
  `security_invoker = true` et filtrage strict des fiches publiées.
- Déclencheur `trg_restaurants_controle_modification` (`BEFORE UPDATE`) interdisant à tout
  non-administrateur de modifier `niveau_verification`, `est_publication_visible`,
  `motif_non_publication`, `statut_validation`, `validation_par`, `validation_le`,
  `derniere_verification_le` ou `commentaire_verification`.
- `search_path = public, pg_temp` fixé sur les **17 fonctions** du schéma `public`, et
  `EXECUTE` révoqué pour `PUBLIC`, `anon` et `restaurateur` sur
  `detecter_doublons`, `valider_fiche_par_controle`, `devalider_fiche` et
  `exiger_acces_administration` (exécutables uniquement par un administrateur actif via
  `exiger_acces_administration()` / `est_administrateur()`).

## Catalogue distribué et catalogue interne (réduction à la génération)

`assets/data/catalogue.json` est **embarqué dans l'application** et publié en ligne
(bouton « Déployer » → GitHub Pages). Une fiche non publiée y conservait son
adresse, son téléphone, sa fourchette de prix et ses services : c'était une
exposition publique, hors de tout parcours applicatif.

- `tools/catalogue/generation.py` applique désormais `reduire_fiche_non_publiee()` :
  une fiche non publiée conserve son identité (nom, commune, type), son motif de
  non-publication et sa provenance, mais aucune donnée pratique (adresse, position,
  contacts, prix, horaires, services, images, menus, exploitation) n'est distribuée.
  Le fichier porte les marqueurs `donnees_pratiques_retirees` et `note_reduction`.
- Le script SQL d'amorçage (`supabase/seed/10_etablissements.sql`) et les sources
  (`data/seed/*.json`) conservent l'intégralité des données : la conservation est
  démontrée par comparaison, la base restant protégée par les policies.
- L'application le dit : `qualiteDistribuee` mesure la complétude sur les fiches
  réellement diffusées, l'écran de diagnostic l'explique, et la file de travail
  interne marque les fiches conservées comme « non publiée : conservée, non diffusée ».
