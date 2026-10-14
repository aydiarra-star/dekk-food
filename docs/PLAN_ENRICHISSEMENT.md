# Plan d'enrichissement du catalogue DEKK FOOD — 2026-10-14

**185 fiches** au total. Ce plan est calculé à partir des données réellement collectées (aucune estimation) : il indique par quoi commencer pour que le recensement progresse de façon vérifiable.

## Priorités

| Priorité | Fiches | Principe |
|---|---|---|
| **P1 — vérification directe** | 105 | L'établissement a un téléphone ou un WhatsApp professionnel : un appel ou un message confirme horaires, menu, prix, services, moyens de paiement, position et recueille l'autorisation d'image. |
| **P2 — contact indirect** | 0 | Seuls un site web, une page professionnelle ou un e-mail sont connus : prise de contact écrite. |
| **P3 — relevé terrain** | 80 | Aucun contact public : sans passage sur place ou appui d'une source locale, la fiche ne peut pas progresser. |

À priorité égale, les **régions les moins couvertes** passent d'abord : c'est le seul levier mesurable pour équilibrer la couverture nationale.

## Ce qu'un appel doit obtenir

| Champ | Ce qui est demandé |
|---|---|
| `horaires` | Horaires réels par jour, jours de fermeture, service midi/soir |
| `telephone` | Numéro professionnel actif (et confirmation de celui déjà collecté) |
| `menu` | Plats et boissons réellement servis, avec prix en FCFA |
| `photos` | Photos de l'établissement fournies par le restaurateur, avec autorisation écrite |
| `gps` | Position exacte (relevé sur place ou partage de localisation) |
| `services` | Sur place, à emporter, livraison, réservation, traiteur |
| `paiement` | Moyens de paiement acceptés (Wave, Orange Money, carte, espèces) |
| `exploitation` | Propriétaire/gérant — uniquement s'il est documenté ou s'il autorise la publication |

L'appel est enregistré comme **source** de la fiche (date, interlocuteur, fonction, informations confirmées). Une information obtenue au téléphone passe la fiche en « partiellement vérifié » ; le badge « vérifié » exige une validation tracée dans la base (`public.valider_fiche_par_controle`), avec la preuve correspondante.

## Charge par région

| Région | Fiches | Dont vérification directe possible (P1) |
|---|---|---|
| Dakar | 61 | 55 |
| Ziguinchor | 33 | 16 |
| Thiès | 28 | 15 |
| Kaolack | 15 | 4 |
| Diourbel | 13 | 4 |
| Saint-Louis | 9 | 6 |
| Louga | 7 | 1 |
| Tambacounda | 7 | 0 |
| Fatick | 4 | 2 |
| Kolda | 3 | 1 |
| Kaffrine | 2 | 1 |
| Matam | 1 | 0 |
| Kédougou | 1 | 0 |
| Sédhiou | 1 | 0 |

## Les 30 premiers appels (extrait de la file de travail)

| # | Fiche | Nom | Région | Commune | Téléphone | WhatsApp | Champs manquants |
|---|---|---|---|---|---|---|---|
| 1 | DF-KA-0001 | Restaurant Tyma Niang | Kaffrine | Kaffrine | +221774615116 | — | menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 2 | DF-KD-0001 | Complexe Hesso | Kolda | Kolda | +221771527681 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 3 | DF-FK-0002 | Cafe de la gare | Fatick | Fatick | +221777286387 | — | menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 4 | DF-FK-0004 | Auberge Restaurant Le Cailcedrat | Fatick | Sokone | +221774305204 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 5 | DF-LG-0001 | Hôtel-Restaurant Il Pellicano | Louga | Louga | +221339870227 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, moyens_de_paiement, verification_humaine |
| 6 | DF-SL-0003 | Aux Délices du fleuve | Saint-Louis | Saint-Louis | +221339614251 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 7 | DF-SL-0001 | Boulanger Ndar Gueth | Saint-Louis | Saint-Louis | — | +221779610099 | horaires, telephone, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 8 | DF-SL-0005 | Coconut cafe | Saint-Louis | Saint-Louis | — | +221774665554 | horaires, telephone, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 9 | DF-SL-0004 | Farmers Coffee Shop Saint-Louis Sénégal | Saint-Louis | Saint-Louis | — | +221772275084 | horaires, telephone, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 10 | DF-SL-0002 | La Saigonnaise | Saint-Louis | Saint-Louis | +221339616481 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 11 | DF-SL-0006 | Restaurant Saharaoui | Saint-Louis | Saint-Louis | +221774221175 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 12 | DF-DB-0001 | Complexe Tawfekh | Diourbel | Diourbel | +221339715219 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, moyens_de_paiement, verification_humaine |
| 13 | DF-DB-0003 | Dibiterie Saf Sap | Diourbel | Touba Mosquée | — | +221766966170 | horaires, telephone, menu_et_prix, photo_authentique, gps_verifie, moyens_de_paiement, verification_humaine |
| 14 | DF-DB-0004 | Resto Savours | Diourbel | Touba Mosquée | — | +221772530207 | horaires, telephone, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 15 | DF-DB-0002 | Épicerie Pâtisserie | Diourbel | Touba Mosquée | — | +221778132555 | horaires, telephone, menu_et_prix, photo_authentique, gps_verifie, moyens_de_paiement, verification_humaine |
| 16 | DF-KL-0004 | La Kaolackoise Restaurant Traiteur | Kaolack | Kaolack | +221776596526 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, moyens_de_paiement, verification_humaine |
| 17 | DF-KL-0001 | Pâtisserie Diadiouba Fast-Food | Kaolack | Kaolack | — | +221781568490 | horaires, telephone, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 18 | DF-KL-0003 | Restaurant Blue Bird | Kaolack | Kaolack | +221339415350 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 19 | DF-KL-0002 | Restaurant LA PALASSE | Kaolack | Kaolack | — | +221776141144 | horaires, telephone, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 20 | DF-TH-0020 | Chez Pascal | Thiès | Joal-Fadiouth | +221777194238 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 21 | DF-TH-0017 | Le Djembé | Thiès | Joal-Fadiouth | +221770945874 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 22 | DF-TH-0012 | La Brioche Dorée Mbour | Thiès | Mbour | +221339575353 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 23 | DF-TH-0002 | La Kaz' Mbour | Thiès | Mbour | +221774128899 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, moyens_de_paiement, verification_humaine |
| 24 | DF-TH-0003 | Le Pelican | Thiès | Ngaparou | +221339586050 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, moyens_de_paiement, verification_humaine |
| 25 | DF-TH-0014 | Salimtoo Cuisinotèque Sénégalaise | Thiès | Ngaparou | — | +221774596725 | horaires, telephone, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 26 | DF-TH-0006 | Le Palm Beach Nianing | Thiès | Nianing | +221339574433 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, moyens_de_paiement, verification_humaine |
| 27 | DF-TH-0005 | L'Escale de Popenguine | Thiès | Popenguine | +221339521111 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, moyens_de_paiement, verification_humaine |
| 28 | DF-TH-0001 | Le Baobab Saly | Thiès | Saly Portudal | +221339571234 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, moyens_de_paiement, verification_humaine |
| 29 | DF-TH-0007 | Le Petit Zing | Thiès | Saly Portudal | +221339570158 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |
| 30 | DF-TH-0008 | Terrou-Bi Saly | Thiès | Saly Portudal | +221339397272 | — | horaires, menu_et_prix, photo_authentique, gps_verifie, services, moyens_de_paiement, verification_humaine |

File complète, triée et exportable : `data/exports/file_de_travail_verification.csv` (185 lignes). Les fiches non publiées y figurent aussi : elles ont besoin d'une vérification avant toute publication.

## Règles qui s'appliquent pendant l'enrichissement

- Aucune donnée n'est inventée : un champ non obtenu reste vide et affiché comme manquant.
- Un prix, un horaire ou un service n'est marqué confirmé qu'avec la source correspondante.
- Une photo n'est publiée qu'avec l'autorisation écrite du restaurateur (référence et date enregistrées) ; à défaut elle reste une illustration générique étiquetée comme telle.
- Le propriétaire n'est publié que s'il est documenté ou s'il autorise explicitement la publication ; sinon « Propriétaire non renseigné ».
- Aucune fusion de fiches automatique : un rapprochement est proposé puis arbitré par un humain.
