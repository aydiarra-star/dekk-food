# Sources, droits et politique de vérification — DEKK FOOD

Ce document décrit **d'où viennent les données** du catalogue, **ce qui est
publiable**, et **comment une information devient « vérifiée »**. Il fait foi en
cas de doute : aucune donnée ne doit entrer dans la base sans respecter ces
règles.

## 1. Sources utilisées et conditions de réutilisation

| Code source | Nature | URL / référence | Conditions retenues |
|---|---|---|---|
| `senefinder` | Annuaire public d'entreprises (fiches déclaratives) | https://senefinder.com/fr/search?category=food_restaurants | Données factuelles uniquement (nom, adresse, téléphone professionnel publié). **Aucune image reprise** : les visuels de l'annuaire sont des banques d'images ou des bannières d'annonceurs. Les fiches ne comportent pas de date de vérification : elles sont classées `a_confirmer` ou `partiellement_verifie`, jamais `verifie`. |
| `senlocal` | Annuaire local, fiches porteuses d'un badge « Vérifié » de l'éditeur | https://senlocal.com/categories/restaurants | Le badge est celui de l'éditeur du site, pas un contrôle DEKK FOOD : les fiches correspondantes sont marquées `partiellement_verifie` et la mention est écrite dans la fiche. Données factuelles seulement. |
| `openstreetmap` | Base cartographique ouverte (requêtes Overpass) | https://www.openstreetmap.org/ — https://overpass-api.de/ (miroir utilisé : https://overpass.openstreetmap.fr/) | **Licence ODbL** : attribution « © OpenStreetMap contributors » conservée dans chaque fiche (identifiant de nœud + date d'extraction). Les positions et horaires sont contributifs donc `gps_verifie = false` et `confirme = false`. Requêtes limitées à des rectangles urbains, sans extraction massive. |
| `application_existante` | Données héritées de l'application DEKK FOOD 2.1.0 | dépôt Git (lib/main.dart historique) | Conservées parce qu'elles décrivent des établissements réels, mais **reclassées « à confirmer »** : elles n'étaient adossées à aucune source. Les affirmations non démontrables (contrôles HACCP, notes d'hygiène) ont été **supprimées**, les prix non sourcés sont affichés « à confirmer ». |
| `restaurateur_terrain` | Informations transmises par l'établissement ou relevées sur place | — | Source de plus haute valeur (horaires, menus, photos autorisées). Nécessite l'accord écrit du restaurateur et devient la `source_id` des éléments concernés. Aucun élément de ce type dans la version actuelle du catalogue. |
| `recherche_web` | Moteur de recherche | — | Utilisé **uniquement comme piste** à vérifier, jamais comme preuve d'activité ou de prix. |

Sources écartées à ce stade : `fadidi.sn` (page inaccessible le 2026-10-13),
`saintlouisdusenegal.com` (contenu « restaurants » rendu par une carte
interactive non extractible sans contourner une protection technique — non fait).

## 2. Ce qui n'entre jamais dans la base

- **Aucun prix, menu, promotion ou frais inventé.** Un prix n'est publié comme
  « confirmé » que s'il est adossé à une source (`plats_prix_source_check` le
  impose en base).
- **Aucun horaire deviné.** Les horaires issus d'OpenStreetMap sont retranscrits
  tels quels et restent `confirme = false`. Par conséquent, l'application
  n'affiche **jamais** de badge « ouvert maintenant » sur ces fiches.
- **Aucune identité de propriétaire déduite d'un nom, d'une photo ou d'une
  initiale.** Un patronyme présent dans un nom public (« chez Coumba SOW »)
  n'est pas repris comme gérant. Par défaut, l'application affiche
  « Propriétaire non renseigné ».
- **Aucune photo réutilisée d'un site tiers.** Les images actuelles sont des
  illustrations de banque d'images, explicitement signalées comme telles à
  l'écran (`est_illustration_generique = true` + légende + licence). Une photo
  authentique exigera une autorisation documentée (auteur, licence/accord, date).
- **Aucune donnée personnelle** (adresse privée, numéro non professionnel,
  identité d'une personne physique sans source publique).
- **Aucune fusion automatique de doublons.**

## 3. Statuts et niveaux de vérification

| Niveau | Signification | Ce que l'application affiche |
|---|---|---|
| `verifie` | Contrôle humain documenté (appel, visite, source officielle datée). | « Vérifié » + date de vérification. |
| `partiellement_verifie` | Fiche reprise d'une source fiable mais non contrôlée par DEKK FOOD (ex. badge « Vérifié » d'un annuaire). | « Partiellement vérifié » + bandeau explicatif. |
| `a_confirmer` | Information trouvée en ligne, non confirmée. | « À confirmer » + bandeau « contactez l'établissement avant de vous déplacer ». |
| `information_indisponible` | L'information n'existe pas dans les sources consultées. | « Information indisponible ». |
| `fermeture_a_verifier` | Signalement de fermeture (temporaire ou définitive) non encore tranché. | « Fermeture à vérifier ». |

Règle générale : **« trouvé en ligne » ≠ « confirmé »**. Chaque fiche porte sa
date de collecte ; chaque contact porte sa source.

## 4. Procédure de revendication par un restaurateur

1. Le restaurateur revendique sa fiche depuis l'application (mode
   « Revendiquer cette fiche ») : il décrit son lien avec l'établissement.
2. La demande est enregistrée puis transmise à l'équipe (table
   `revendications`, statut `en_attente`).
3. La preuve du lien est contrôlée (appel au numéro professionnel publié,
   e-mail sur le domaine de l'établissement, courrier sur papier à en-tête).
4. Après validation, le compte est rattaché à l'établissement
   (`utilisateurs_admin.restaurant_id`), **sans jamais** passer la fiche en
   `verifie` automatiquement : la modification reste tracée dans
   `journal_modifications` et le niveau de vérification ne peut être changé que
   par un administrateur.
5. Toute correction demandée est appliquée après contrôle, sans écrasement
   silencieux : l'historique complet des modifications est conservé.

## 5. Droits des personnes et retrait

Toute personne peut demander la correction ou le retrait d'une information la
concernant depuis « Signaler une erreur » ou « Demander une mise à jour ».
Les demandes sont conservées dans `demandes_correction` / `signalements` et
traitées avant publication. En l'absence de base connectée, l'application
indique explicitement que la contribution reste **locale** et n'est ni publiée
ni transmise.

## 6. Limites documentées de la collecte (2026-10-13)

- Les annuaires publics consultés sont très fortement concentrés sur Dakar ;
  ils publient peu de coordonnées GPS et aucune date de vérification.
- La **région de Matam** n'a renvoyé aucun établissement nommé dans les sources
  consultées (un seul nœud OpenStreetMap, sans nom) : elle reste sans fiche
  plutôt que d'être remplie par des données inventées.
- Aucun contrôle téléphonique n'a encore été effectué : les taux de
  confirmation sont donc nuls, et l'application le dit à l'écran.
- Les établissements sans présence en ligne (gargotes, dibiteries de quartier)
  ne pourront être couverts que par relevé terrain ou signalement.

## Relevés OpenStreetMap du 13/10/2026 — méthode et exclusions

Extractions `amenity in (restaurant, fast_food, cafe)` sur des rectangles urbains, via le
miroir `overpass.openstreetmap.fr` (l'API principale répondait « server too busy »).
**84 fiches** en sont issues, toutes en `a_confirmer`, `gps_verifie = false`, avec
l'identifiant du nœud ou du chemin et la date d'extraction.

Communes avec au moins un résultat (18) : Bignona, Diembéring, Diourbel, Fatick, Joal-Fadiouth, Kaffrine, Kaolack, Kolda, Kébémer, Kédougou, Louga, Ourossogui, Richard-Toll, Sokone, Sédhiou, Tambacounda, Tivaouane, Touba Mosquée.

Agglomérations interrogées **sans aucun POI nommé** : Matam-ville, Vélingara, Foundiougne,
Kanel, Guinguinéo, Nioro du Rip, Podor, Mékhé, Linguère, Sédhiou, Kédougou (villes), Saint-Louis
(ville), Goudomp, Bounkiling, Salémata, Oussouye, Toubakouta, Birkelane. Une absence dans OpenStreetMap **ne prouve pas** l'absence de restaurants : elle
signifie que la zone est peu ou pas cartographiée. Ces villes restent à couvrir par d'autres
sources ou par relevé terrain.

Fiches écartées volontairement (et pourquoi) :
- noms génériques sans identité propre (« Restaurant », « Dibiterie », « Bar ») ;
- bars sans restauration déclarée (« Bar » et « Pink Bar » à Ourossogui) ;
- `amenity=internet_cafe` (« Multi Services Business » à Kaolack, « Miname Techno » à Touba) ;
- doublon inter-sources arbitré manuellement (« Dibiterie Saf Sap », voir `docs/RAPPORT.md`).

Les tags déclaratifs (`opening_hours`, `diet:*`, `wheelchair`, `stars`, `smoking`) sont
retranscrits comme déclaratifs : aucun horaire, prix ou service n'en a été déduit.

## Procédure de revendication et de correction d'une fiche

Toute fiche peut être corrigée ou revendiquée par l'établissement concerné. **Une
revendication ne vaut jamais vérification** : elle ouvre un contrôle, elle ne
l'attribue pas. La base l'impose (trigger `controler_revendication`) et le pipeline
l'applique (aucune fiche n'est « vérifiée » sans validation tracée).

### 1. Qui peut demander

Le responsable de l'établissement (propriétaire, gérant, responsable de salle),
ou toute personne qui constate une erreur, une fermeture ou une donnée personnelle
à retirer. Un visiteur peut signaler une erreur sans être le responsable.

### 2. Ce qu'il faut fournir

| Élément | Pourquoi |
|---|---|
| Nom et fonction du demandeur | Identifier l'interlocuteur (jamais publié sans accord) |
| E-mail professionnel et/ou téléphone | Recontacter la demande |
| Lien de la fiche concernée (URL ou numéro `DF-XX-NNNN`) | Traiter la bonne fiche |
| Nature de la demande | Correction, revendication, retrait d'information, fermeture |
| Preuve du lien avec l'établissement | Domaine de l'e-mail, document officiel, appel vérifié, site/pages officielles |

### 3. Preuves acceptées pour l'identité

`email_domaine` (adresse sur le domaine de l'établissement), `document_officiel`
(registre de commerce, licence, facture), `appel` (vérification téléphonique
consignée), `site_web` (mention officielle), `autre` (à justifier). La référence de
la preuve est enregistrée (`preuve_reference`), ainsi que la personne qui a contrôlé
(`verifie_par`) et la date (`verifie_le`).

### 4. Ce que la procédure change — et ne change pas

- **Change** : les coordonnées, horaires, services et menus **lorsqu'ils sont
  fournis par le responsable** (la source devient « déclaration du restaurateur »,
  datée) ; l'ajout de photos **avec autorisation écrite** (référence et date
  enregistrées) ; le signalement d'une fermeture (statut « fermeture à vérifier »,
  affiché comme tel).
- **Ne change pas** : le niveau de vérification. Le badge « vérifié » exige un
  contrôle humain tracé (`public.valider_fiche_par_controle`), avec la preuve
  correspondante. Un restaurateur ne peut pas s'auto-attribuer ce badge (RLS +
  contrainte `restaurants_verifie_exige_validation_check`).
- **Ne change pas non plus** : le statut d'une fiche qui appartient à un autre
  établissement. En cas de conflit entre deux demandeurs, la fiche reste en
  « à confirmer » jusqu'à résolution.

### 5. Retrait d'information et droit de réponse

Une demande de retrait (donnée personnelle, photo litigieuse, information
commerciale sensible) est traitée **avant** toute autre : l'information est
dépubliée ou remplacée par une mention neutre, la fiche restant en ligne sans
l'élément contesté. Aucune donnée n'est effacée sans trace : la dépublication est
motivée et journalisée (`motif_non_publication`, `journal_modifications`).

### 6. Délais et traçabilité

| Étape | État | Effet |
|---|---|---|
| Demande reçue | `en_attente` | Rien ne change automatiquement |
| Preuve en cours d'examen | `en_verification` | Rien ne change |
| Preuve validée | `verifiee` | Le lien est reconnu ; les informations fournies sont intégrées avec leur source |
| Demande rejetée | `rejetee` | **Motif obligatoire** (contrainte de base) |

### 7. Ce qui reste à construire

L'interface publique de correction/revendication (formulaire) et l'écran
d'administration de traitement (arbitrage des doublons, file de validation) ne sont
pas encore développés. La procédure ci-dessus décrit le circuit que ces interfaces
devront respecter.

## Sources complémentaires étudiées pour les régions peu couvertes

Les relevés OpenStreetMap ont atteint leur limite : 18 communes ont livré des
résultats, mais Matam-ville, Kanel, Ranérou, Podor, Linguère, Mékhé, Nioro du Rip,
Foundiougne, Vélingara, Goudomp, Bounkiling, Salémata, Oussouye, Toubakouta,
Birkelane, Sédhiou, Kédougou et Saint-Louis (villes) n'ont **aucun POI nommé**.
L'absence dans OpenStreetMap ne prouve pas l'absence de restaurants : elle signifie
que la zone est peu ou pas cartographiée.

| Source candidate | Intérêt réel | Conditions | Verdict |
|---|---|---|---|
| **Wikidata / requête SPARQL** (`query.wikidata.org`) | Données structurées et réutilisables (licence CC0), coordonnées géographiques horodatées : utile pour recouper une position. | CC0, requêtage autorisé avec attribution. | **À brancher** (aucune donnée encodée pour l'instant) : le nombre d'établissements sénégalais référencés est à mesurer avant de compter dessus. |
| **Pages professionnelles publiques** (Facebook, Instagram d'établissements) | Adresse, horaires, photos publiés par l'établissement lui-même : la source la plus proche de l'établissement sans contact direct. | Consultation manuelle uniquement. **Aucun moissonnage automatisé** (conditions d'utilisation) ; les photos ne sont pas reprises sans autorisation. | **À utiliser manuellement**, fiche par fiche, en renseignant source et date. |
| **Office du tourisme / mairies / associations de restaurateurs** (Saint-Louis, Ziguinchor, Matam, Tambacounda, Kédougou) | Listes locales, y compris d'établissements sans présence en ligne — la seule voie pour les zones non cartographiées. | Demande écrite, réutilisation à négocier, autorisation de publication à obtenir. | **À demander** : c'est le levier identifié pour Matam, Ranérou, Goudomp, Salémata. |
| **Registre de commerce / données ouvertes publiques** | Existence légale d'entreprises de restauration, parfois par région. | Licences et conditions de réutilisation à vérifier au cas par cas ; aucune donnée personnelle. | **À explorer** (aucune démarche engagée). |
| **Pages d'avis en ligne** | Signalement de fermetures et changements d'adresse. | Conditions d'utilisation souvent restrictives ; contenu non réutilisable, non fiable pour une donnée publiée. | **Usage indirect seulement** : jamais comme source d'une fiche publiée. |
| **Institutions et services de livraison** | Établissements référencés dans une zone donnée. | Contrats et bases de données privées : rien n'est réutilisable sans accord écrit. | **À écarter sans partenariat explicite.** |

**Priorité opérationnelle** : les 105 fiches joignables (P1, voir
`docs/PLAN_ENRICHISSEMENT.md`) d'abord, car un appel confirme en une fois les
horaires, le menu, les prix, la position et l'accord d'image. Les zones sans POI
cartographié (P3) passent par une source locale ou un relevé terrain : c'est le
chantier le plus lourd, et il ne peut pas être comblé par du moissonnage.

