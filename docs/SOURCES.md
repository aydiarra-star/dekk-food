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
| `openstreetmap` | Base cartographique ouverte (requêtes Overpass) | https://www.openstreetmap.org/ — https://overpass-api.de/ | **Licence ODbL** : attribution « © OpenStreetMap contributors » conservée dans chaque fiche (identifiant de nœud + date d'extraction). Les positions et horaires sont contributifs donc `gps_verifie = false` et `confirme = false`. Requêtes limitées à des rectangles urbains, sans extraction massive. |
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
