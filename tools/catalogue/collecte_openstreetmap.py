"""Collecte « annonces cartographiques publiques » : OpenStreetMap (licence ODbL).

Les données ci-dessous ont été relevées le 2026-10-13 via l'API Overpass
(requêtes limitées à des rectangles de recherche urbains), dans le respect des
conditions d'utilisation : pas de contournement de protection, attribution ODbL
conservée dans chaque fiche (identifiant du nœud/chemin et date d'extraction).

Objectifs de cette source :
- couvrir les régions que les annuaires grand public ignorent (Fatick, Kaffrine,
  Tambacounda, Kédougou, Sédhiou) ;
- disposer de coordonnées réellement publiées (jamais inventées) ;
- documenter les limites : ces positions sont communautaires, donc marquées
  `gps_verifie = false` et rattachées à la source `openstreetmap`.

Usage : python3 tools/catalogue/collecte_openstreetmap.py
"""

from __future__ import annotations

import json
from pathlib import Path

DATE = "2026-10-13"
OSM = "openstreetmap"
EXTRACTION = "OpenStreetMap (ODbL), extraction du 2026-10-13"


class FicheOsm:
    def __init__(
        self,
        numero: str,
        nom: str,
        ville_slug: str,
        osm_type: str,
        osm_id: int,
        latitude: float,
        longitude: float,
        region: str,
        departement: str,
        commune: str,
        type_etablissement: str,
        categories: list[str],
        description: str,
        adresse_complete: str | None = None,
        quartier: str | None = None,
        telephone: str | None = None,
        site_web: str | None = None,
        horaires: list[dict] | None = None,
        services: list[str] | None = None,
    ) -> None:
        self.numero = numero
        self.nom = nom
        self.ville_slug = ville_slug
        self.osm_type = osm_type
        self.osm_id = osm_id
        self.latitude = latitude
        self.longitude = longitude
        self.region = region
        self.departement = departement
        self.commune = commune
        self.type_etablissement = type_etablissement
        self.categories = categories
        self.description = description
        self.adresse_complete = adresse_complete
        self.quartier = quartier
        self.telephone = telephone
        self.site_web = site_web
        self.horaires = horaires or []
        self.services = services or []

    @property
    def url(self) -> str:
        return f"https://www.openstreetmap.org/{self.osm_type}/{self.osm_id}"

    @property
    def cle(self) -> str:
        return f"{OSM}:{self.osm_type}/{self.osm_id}"

    def as_dict(self) -> dict:
        contacts = []
        if self.telephone:
            contacts.append(
                {
                    "type": "telephone",
                    "valeur": self.telephone,
                    "confirme": False,
                    "source": OSM,
                    "source_url": self.url,
                }
            )
        if self.site_web:
            contacts.append(
                {
                    "type": "site_web",
                    "valeur": self.site_web,
                    "confirme": False,
                    "source": OSM,
                    "source_url": self.url,
                }
            )
        return {
            "cle": self.cle,
            "numero_fiche": self.numero,
            "nom": self.nom,
            "slug": _slug(self.nom, self.ville_slug),
            "type_etablissement": self.type_etablissement,
            "categories": self.categories,
            "description_courte": f"{self.description} {EXTRACTION}, {self.osm_type} {self.osm_id} : "
            "position communautaire, non confirmée sur place par DEKK FOOD.",
            "statut": "a_verifier",
            "niveau_verification": "a_confirmer",
            "adresse": {
                "region": self.region,
                "departement": self.departement,
                "commune": self.commune,
                "quartier_libre": self.quartier,
                "adresse_complete": self.adresse_complete,
                "latitude": self.latitude,
                "longitude": self.longitude,
                "gps_verifie": False,
            },
            "contacts": contacts,
            "services": self.services,
            "horaires": self.horaires,
            "images": [],
            "menus": [],
            "sources": [
                {
                    "source": OSM,
                    "url": self.url,
                    "date_collecte": DATE,
                    "donnees": "nom, coordonnées, type"
                    + (", téléphone" if self.telephone else "")
                    + (", horaires publiés" if self.horaires else ""),
                    "niveau_confiance": "moyen",
                }
            ],
            "date_collecte": DATE,
            "origine_donnee": OSM,
            "est_publication_visible": True,
        }


def _slug(nom: str, ville: str) -> str:
    import unicodedata

    base = unicodedata.normalize("NFKD", nom.lower())
    base = "".join(caractere for caractere in base if not unicodedata.combining(caractere))
    base = base.replace("'", "-").replace("\u2019", "-").replace("&", "-")
    base = "".join(caractere if caractere.isalnum() else "-" for caractere in base)
    while "--" in base:
        base = base.replace("--", "-")
    ville_propre = "".join(caractere if caractere.isalnum() else "-" for caractere in ville.lower())
    return f"{base.strip('-')}-{ville_propre.strip('-')}"


def _horaires_osm(valeur: str, url: str) -> list[dict]:
    """Retranscrit les horaires publiés sur OSM, sans les interpréter au-delà.

    « 24/7 » ouvre tous les jours de 00:00 à 23:59 ; « Mo-Su hh:mm-hh:mm »
    applique la même plage à toute la semaine. Tout autre format est conservé
    comme texte dans la description plutôt que deviné ici.
    """
    if valeur == "24/7":
        return [
            {
                "jour": jour,
                "service": "continu",
                "ouverture": "00:00",
                "fermeture": "23:59",
                "ferme": False,
                "confirme": False,
                "source": OSM,
                "source_url": url,
                "date_verification": None,
            }
            for jour in range(7)
        ]
    if valeur.startswith("Mo-Su "):
        plage = valeur.replace("Mo-Su ", "", 1)
        if ":" in plage and "-" in plage:
            ouverture, _, fermeture = plage.partition("-")
            return [
                {
                    "jour": jour,
                    "service": "continu",
                    "ouverture": ouverture.strip(),
                    "fermeture": fermeture.strip(),
                    "ferme": False,
                    "confirme": False,
                    "source": OSM,
                    "source_url": url,
                    "date_verification": None,
                }
                for jour in range(7)
            ]
    return []


def main() -> None:
    fiches = [
        # ------------------------------------------------------------- Fatick
        FicheOsm(
            "DF-FK-0001", "Tanti", "fatick", "node", 4788392811, 14.3297539, -16.4038844,
            "Fatick", "Fatick", "Fatick", "restaurant", ["senegalaise"],
            "Restaurant référencé sur OpenStreetMap à Fatick (capacité déclarée 20 places, vente à emporter).",
            quartier="Fatick", services=["a_emporter"],
        ),
        FicheOsm(
            "DF-FK-0002", "Cafe de la gare", "fatick", "node", 8598559615, 14.3444471, -16.4203542,
            "Fatick", "Fatick", "Fatick", "cafe_restaurant", ["petit_dejeuner"],
            "Café référencé sur OpenStreetMap à Fatick, connexion Wi-Fi annoncée gratuite (SSID « cafedugare »).",
            adresse_complete="Fatick", quartier="Gare", telephone="+221777286387",
            horaires=_horaires_osm("24/7", "https://www.openstreetmap.org/node/8598559615"),
        ),
        # ----------------------------------------------------------- Kaffrine
        FicheOsm(
            "DF-KA-0001", "Restaurant Tyma Niang", "kaffrine", "node", 5366801721, 14.0973368, -15.5567383,
            "Kaffrine", "Kaffrine", "Kaffrine", "restaurant", ["senegalaise"],
            "Restaurant référencé sur OpenStreetMap à Kaffrine. Le nom publié par la source comporte un "
            "patronyme (« chez Coumba SOW ») : il n'est pas repris ici comme identité de propriétaire, "
            "aucune source ne documentant la gérance.",
            adresse_complete="Kaffrine", quartier="Centre", telephone="774615116",
            horaires=_horaires_osm("Mo-Su 08:00-23:00", "https://www.openstreetmap.org/node/5366801721"),
        ),
        FicheOsm(
            "DF-KA-0002", "Hôtel Keur Venus", "kaffrine", "way", 1033465752, 14.1031834, -15.5491021,
            "Kaffrine", "Kaffrine", "Kaffrine", "restaurant_hotel",
            ["burgers", "pizza", "fruits_de_mer", "grillades", "internationale"],
            "Hôtel-restaurant référencé sur OpenStreetMap à Kaffrine (Escale) : burgers, pizzas, poulet, "
            "sandwichs, fruits de mer et grillades annoncés, cuisine halal déclarée, service 24/7.",
            adresse_complete="Escale, Kaffrine", quartier="Escale",
            horaires=_horaires_osm("24/7", "https://www.openstreetmap.org/way/1033465752"),
        ),
        # ------------------------------------------------------- Tambacounda
        FicheOsm(
            "DF-TB-0001", "Chez Eva", "tambacounda", "node", 4283971717, 13.7748981, -13.6726426,
            "Tambacounda", "Tambacounda", "Tambacounda", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap au centre de Tambacounda.",
            adresse_complete="Tambacounda", quartier="Centre",
        ),
        FicheOsm(
            "DF-TB-0002", "La Hortensia", "tambacounda", "node", 4283975533, 13.7747348, -13.6770152,
            "Tambacounda", "Tambacounda", "Tambacounda", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap le long de la route nationale 1 à Tambacounda.",
            adresse_complete="Route nationale 1, Tambacounda", quartier="Centre",
        ),
        FicheOsm(
            "DF-TB-0003", "La Petite Baraque 5 Étoiles", "tambacounda", "node", 5538419822, 13.7766396, -13.6748332,
            "Tambacounda", "Tambacounda", "Tambacounda", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Tambacounda.",
            adresse_complete="Tambacounda", quartier="Centre",
        ),
        FicheOsm(
            "DF-TB-0004", "Gueye Services", "tambacounda", "node", 6784956929, 13.7657965, -13.6754546,
            "Tambacounda", "Tambacounda", "Tambacounda", "restaurant", [],
            "Établissement de restauration référencé sur OpenStreetMap à Tambacounda (position relevée "
            "sur le terrain par un contributeur OSM).",
            adresse_complete="Tambacounda", quartier="Sud",
        ),
        FicheOsm(
            "DF-TB-0005", "Saveurs orientales", "tambacounda", "node", 7705155486, 13.7843207, -13.6742281,
            "Tambacounda", "Tambacounda", "Tambacounda", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap au nord du centre de Tambacounda.",
            adresse_complete="Tambacounda", quartier="Nord",
        ),
        FicheOsm(
            "DF-TB-0006", "Best burger", "tambacounda", "node", 8165136278, 13.7742977, -13.6756985,
            "Tambacounda", "Tambacounda", "Tambacounda", "fast_food", ["burgers", "street_food"],
            "Fast-food référencé sur OpenStreetMap à Tambacounda, en face de la route nationale 1.",
            adresse_complete="En face de la route nationale 1, Tambacounda", quartier="Centre",
            horaires=_horaires_osm("Mo-Su 09:00-03:00", "https://www.openstreetmap.org/node/8165136278"),
        ),
        FicheOsm(
            "DF-TB-0007", "Le Relais de Tamba", "tambacounda", "way", 243590824, 13.7741602, -13.6988486,
            "Tambacounda", "Tambacounda", "Tambacounda", "restaurant_hotel", [],
            "Hôtel-restaurant référencé sur OpenStreetMap Route de Kaolack à Tambacounda (22 chambres).",
            adresse_complete="Route de Kaolack, Tambacounda", quartier="Kaolack",
            site_web="https://www.horizons-bleus-senegal.com/?-Le-relais-de-Tamba-",
        ),
        # ------------------------------- Richard-Toll (région de Saint-Louis)
        FicheOsm(
            "DF-SL-0007", "Restaurant chez-soi", "richard-toll", "node", 9085125463, 16.4649240, -15.6809820,
            "Saint-Louis", "Dagana", "Richard-Toll", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Richard-Toll (seule fiche nommée de la ville au "
            "moment de l'extraction).",
            adresse_complete="Richard-Toll",
        ),
        FicheOsm(
            "DF-SL-0008", "Burger City", "richard-toll", "node", 9085129867, 16.4670861, -15.7034560,
            "Saint-Louis", "Dagana", "Richard-Toll", "fast_food", ["burgers", "street_food"],
            "Fast-food référencé sur OpenStreetMap à Richard-Toll.",
            adresse_complete="Richard-Toll",
        ),
        FicheOsm(
            "DF-SL-0009", "Le Walo", "richard-toll", "node", 12738922213, 16.4678299, -15.7067277,
            "Saint-Louis", "Dagana", "Richard-Toll", "fast_food", ["senegalaise", "grillades"],
            "Établissement référencé sur OpenStreetMap à Richard-Toll : « plat du jour et dibi » "
            "(mention publiée par la source).",
            adresse_complete="Richard-Toll",
        ),
        # ----------------------------- Matam, Louga, Kolda (relevés 2026-10-13)
        FicheOsm(
            "DF-MT-0001", "Samassa", "ourossogui", "way", 582266136, 15.6092990, -13.3184344,
            "Matam", "Matam", "Ourossogui", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Ourossogui (agglomération de Matam). La source ne publie ni horaire, ni contact, ni prix.",
            adresse_complete="Ourossogui",
        ),
        FicheOsm(
            "DF-LG-0002", "Chez Racky", "louga", "node", 1775105881, 15.6217091, -16.2250047,
            "Louga", "Louga", "Louga", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Louga. La fiche OSM porte la mention « source : GPS survey » (relève d'un contributeur, non vérifiée par DEKK FOOD).",
            adresse_complete="Louga",
        ),
        FicheOsm(
            "DF-LG-0003", "Itam Ndajé Mi", "louga", "node", 1775978039, 15.6220710, -16.2225901,
            "Louga", "Louga", "Louga", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Louga. La fiche OSM porte la mention « source : GPS survey » (relève d'un contributeur, non vérifiée par DEKK FOOD).",
            adresse_complete="Louga",
        ),
        FicheOsm(
            "DF-LG-0004", "Fast Food le Diambour", "louga", "node", 1810631642, 15.6233172, -16.2192088,
            "Louga", "Louga", "Louga", "fast_food", [],
            "Fast-food référencé sur OpenStreetMap à Louga ; la source le classe en cuisine régionale (tag cuisine=regional). Aucun contact publié.",
            adresse_complete="Louga",
        ),
        FicheOsm(
            "DF-LG-0005", "Restaurant d'application du CFP", "louga-cfp", "node", 4751286620, 15.6267039, -16.2336096,
            "Louga", "Louga", "Louga", "restaurant", [],
            "Restaurant d'application d'un centre de formation professionnelle, référencé sur OpenStreetMap à Louga (tag addr:city=Louga). L'ouverture au grand public n'est pas confirmée par la source.",
            adresse_complete="Louga",
        ),
        FicheOsm(
            "DF-KD-0002", "Complexe Délicia", "kolda", "node", 7575282485, 12.8897156, -14.9394955,
            "Kolda", "Kolda", "Kolda", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Kolda. La source ne publie ni horaire, ni contact, ni prix.",
            adresse_complete="Kolda",
        ),
        FicheOsm(
            "DF-KD-0003", "TedoungalFouladou", "kolda", "node", 7853237214, 12.8921231, -14.9406461,
            "Kolda", "Kolda", "Kolda", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Kolda. La source ne publie ni horaire, ni contact, ni prix.",
            adresse_complete="Kolda",
        ),
        # --------------- Kaolack, Diourbel et Touba (relevés Overpass 2026-10-13)
        FicheOsm(
            "DF-KL-0005", "Le Brasero - chez Anouar", "kaolack", "node", 4966108121, 14.1387424, -16.0734762,
            "Kaolack", "Kaolack", "Kaolack", "restaurant", ['libanaise', 'grillades', 'pizza'],
            "Restaurant référencé sur OpenStreetMap à Kaolack. La source déclare les cuisines poulet, libanaise, grillades et pizza, ainsi qu'une ouverture déclarative Mo-Su 07:30-22:00 (non confirmée). Noms alternatifs publiés par la source : Annoire's (en, fr)."
        ),
        FicheOsm(
            "DF-KL-0006", "Chez Ami Collé", "kaolack", "node", 5320654424, 14.0882000, -16.0632400,
            "Kaolack", "Kaolack", "Kaolack", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Kaolack. Ni horaire ni contact publiés par la source."
        ),
        FicheOsm(
            "DF-KL-0007", "Chez touré", "kaolack", "node", 5320654446, 14.0903954, -16.0648331,
            "Kaolack", "Kaolack", "Kaolack", "fast_food", [],
            "Fast-food référencé sur OpenStreetMap à Kaolack. Ni horaire ni contact publiés par la source."
        ),
        FicheOsm(
            "DF-KL-0008", "Le Maty", "kaolack", "node", 5416462722, 14.1382405, -16.0725312,
            "Kaolack", "Kaolack", "Kaolack", "fast_food", [],
            "Fast-food référencé sur OpenStreetMap à Kaolack. La source ne publie ni horaire ni contact."
        ),
        FicheOsm(
            "DF-KL-0009", "restaurant machallah", "kaolack", "node", 6054865069, 14.1373902, -16.0795601,
            "Kaolack", "Kaolack", "Kaolack", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Kaolack. La source contient une seconde fiche très proche (« Macha Alah », à environ 100 m) : un recoupement humain est nécessaire avant tout rapprochement (aucune fusion automatique)."
        ),
        FicheOsm(
            "DF-KL-0010", "Macha Alah", "kaolack", "node", 6054872708, 14.1378029, -16.0787628,
            "Kaolack", "Kaolack", "Kaolack", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Kaolack. La source contient une seconde fiche très proche (« restaurant machallah », à environ 100 m) : recoupement humain nécessaire, aucune fusion automatique."
        ),
        FicheOsm(
            "DF-KL-0011", "Chez Mère Oulèye", "kaolack", "node", 9522827201, 14.1793529, -16.0746687,
            "Kaolack", "Kaolack", "Kaolack", "restaurant", ['street_food', 'vegetarienne'],
            "Restaurant référencé sur OpenStreetMap à Kaolack. La source déclare une offre café, sandwich et poulet ainsi que la présence de plats à base de viande et de plats végétariens (tags diet:meat et diet:vegetarian, déclaratifs et non confirmés)."
        ),
        FicheOsm(
            "DF-KL-0012", "Chez Abass", "kaolack", "node", 11381104669, 14.1697736, -16.0744706,
            "Kaolack", "Kaolack", "Kaolack", "fast_food", [],
            "Fast-food référencé sur OpenStreetMap à Kaolack (Route de Gossas). Nom alternatif publié par la source : Maïga Abass.",
            adresse_complete="Route de Gossas, Kaolack",
        ),
        FicheOsm(
            "DF-KL-0013", "RESTAURANT LA DONIA IVOIRIENNE", "kaolack", "node", 11949729829, 14.1404870, -16.0774764,
            "Kaolack", "Kaolack", "Kaolack", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Kaolack. Nom publié tel quel par la source ; ni horaire ni contact publiés."
        ),
        FicheOsm(
            "DF-KL-0014", "Tangana", "kaolack", "node", 11958155653, 14.1406471, -16.0810435,
            "Kaolack", "Kaolack", "Kaolack", "fast_food", [],
            "Fast-food référencé sur OpenStreetMap à Kaolack. Homonyme relevé au même moment à Touba (région de Diourbel) : établissements distincts, aucune fusion automatique."
        ),
        FicheOsm(
            "DF-KL-0015", "Restaurant Serigne Fallou", "kaolack", "node", 11958207817, 14.1410829, -16.0812150,
            "Kaolack", "Kaolack", "Kaolack", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Kaolack (Kasnack Nord). Ni horaire ni contact publiés.",
            adresse_complete="Kasnack Nord, Kaolack",
        ),
        FicheOsm(
            "DF-DB-0005", "Pizza Gora", "diourbel", "node", 4228039581, 14.6557052, -16.2345001,
            "Diourbel", "Diourbel", "Diourbel", "restaurant", ['pizza'],
            "Restaurant référencé sur OpenStreetMap à Diourbel (nationale N3), spécialisé pizza selon la source. Ni horaire ni contact publiés.",
            adresse_complete="N3, Diourbel",
        ),
        FicheOsm(
            "DF-DB-0006", "Matt Gui", "diourbel", "node", 7185249489, 14.6504590, -16.2335495,
            "Diourbel", "Diourbel", "Diourbel", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Diourbel ; la source publie aussi le nom wolof « Matt gi »."
        ),
        FicheOsm(
            "DF-DB-0007", "Sope S.Fallou", "touba", "node", 5232752968, 14.8415689, -15.8687240,
            "Diourbel", "Mbacké", "Touba Mosquée", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Touba. Ni horaire ni contact publiés par la source."
        ),
        FicheOsm(
            "DF-DB-0008", "Buvett Sopes Mbacke Sokhna Lo", "touba", "node", 5232752969, 14.8415235, -15.8686984,
            "Diourbel", "Mbacké", "Touba Mosquée", "cafe_restaurant", [],
            "Point de vente référencé sur OpenStreetMap à Touba (amenity=cafe). Ni horaire ni contact publiés."
        ),
        FicheOsm(
            "DF-DB-0009", "Poulet de Chair", "touba", "node", 5232752972, 14.8412961, -15.8686099,
            "Diourbel", "Mbacké", "Touba Mosquée", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Touba. Ni horaire ni contact publiés par la source."
        ),
        FicheOsm(
            "DF-DB-0010", "Tangana", "touba", "node", 5242415246, 14.8587503, -15.8900023,
            "Diourbel", "Mbacké", "Touba Mosquée", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Touba. Homonyme relevé au même moment à Kaolack (établissements distincts) : aucune fusion automatique."
        ),
        FicheOsm(
            "DF-DB-0011", "Dibiterie Serigne fallou", "touba", "node", 5242482406, 14.8619367, -15.8798933,
            "Diourbel", "Mbacké", "Touba Mosquée", "dibiterie", [],
            "Dibiterie référencée sur OpenStreetMap à Touba. Ni horaire ni contact publiés par la source."
        ),
        FicheOsm(
            "DF-DB-0012", "Super saf TAGANA", "touba", "node", 5242483393, 14.8600528, -15.8850487,
            "Diourbel", "Mbacké", "Touba Mosquée", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Touba. Ni horaire ni contact publiés par la source."
        ),
        # DF-DB-0013 « Dibiterie Saf Sap » (node 5242525308) a été retirée le 13/10/2026 :
        # le dédoublonnage l'a signalée comme doublon inter-sources de la fiche senefinder
        # DF-DB-0003 (nom et téléphone identiques). Les coordonnées GPS ont été reportées
        # sur la fiche DF-DB-0003 plutôt que de créer un doublon dans le catalogue.
        FicheOsm(
            "DF-DB-0014", "Sokhna Baly Mountakha", "touba", "node", 5242685624, 14.8602370, -15.8773240,
            "Diourbel", "Mbacké", "Touba Mosquée", "fast_food", [],
            "Fast-food référencé sur OpenStreetMap à Touba. Ni horaire ni contact publiés par la source."
        ),
        # ------------------- Joal-Fadiouth, Tivaouane, Kébémer (relevés Overpass 2026-10-13)
        FicheOsm(
            "DF-TH-0015", "La Taverne du Pêcheur", "joal-fadiouth", "node", 1881107248, 14.1529993, -16.8297193,
            "Thi\u00e8s", "Mbour", "Joal-Fadiouth", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Joal. Ni horaire ni contact publiés par la source.",
            adresse_complete="Joal",
        ),
        FicheOsm(
            "DF-TH-0016", "Restaurant Djiba", "joal-fadiouth", "node", 2578467357, 14.2234514, -16.8151018,
            "Thi\u00e8s", "Mbour", "Joal-Fadiouth", "restaurant", ['senegalaise'],
            "Restaurant référencé sur OpenStreetMap près de Joal-Fadiouth ; la source le classe en cuisine sénégalaise. Ni horaire ni contact publiés.",
        ),
        FicheOsm(
            "DF-TH-0017", "Le Djembé", "joal-fadiouth", "node", 5017985821, 14.1532349, -16.8350389,
            "Thi\u00e8s", "Mbour", "Joal-Fadiouth", "restaurant", ['senegalaise', 'francaise'],
            "Restaurant référencé sur OpenStreetMap à Joal ; la source déclare une cuisine locale et française avec service de café, une ouverture déclarative Mo-Su 11:00-22:00 (non confirmée) et un accès fauteuil roulant signalé comme non praticable. Téléphone et site web publiés par la source, non appelés ni vérifiés par DEKK FOOD.",
            telephone="+221 77 094 58 74",
            site_web="https://www.auberge-djembe.com/",
        ),
        FicheOsm(
            "DF-TH-0018", "Chez Clémence", "joal-fadiouth", "node", 9876348830, 14.1604840, -16.8406132,
            "Thi\u00e8s", "Mbour", "Joal-Fadiouth", "restaurant", ['senegalaise'],
            "Restaurant référencé sur OpenStreetMap à Joal ; la source le classe en cuisine régionale.",
        ),
        FicheOsm(
            "DF-TH-0019", "\"Coin apéro\" de Louise Faye", "joal-fadiouth", "node", 11819495772, 14.1357426, -16.7767203,
            "Thi\u00e8s", "Mbour", "Joal-Fadiouth", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap dans la zone de Joal-Fadiouth ; la commune exacte reste à confirmer lors d'un relevé terrain. Ni horaire ni contact publiés par la source.",
        ),
        FicheOsm(
            "DF-TH-0020", "Chez Pascal", "joal-fadiouth", "node", 12748082712, 14.1532333, -16.8247012,
            "Thi\u00e8s", "Mbour", "Joal-Fadiouth", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Joal. Le téléphone publié par la source n'a pas été appelé : il reste à confirmer.",
            telephone="+221 77 719 42 38",
        ),
        FicheOsm(
            "DF-TH-0021", "La Metisse", "joal-fadiouth", "way", 558916323, 14.1577332, -16.8376377,
            "Thi\u00e8s", "Mbour", "Joal-Fadiouth", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Joal. Ni horaire ni contact publiés par la source.",
        ),
        FicheOsm(
            "DF-TH-0022", "restaurant khadi", "tivaouane", "node", 4408092550, 14.9596099, -16.8082083,
            "Thi\u00e8s", "Tivaouane", "Tivaouane", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Tivaouane. Ni horaire ni contact publiés par la source.",
        ),
        FicheOsm(
            "DF-TH-0023", "chez papino", "tivaouane", "node", 4409501739, 14.9489208, -16.8123410,
            "Thi\u00e8s", "Tivaouane", "Tivaouane", "fast_food", [],
            "Fast-food référencé sur OpenStreetMap à Tivaouane. Ni horaire ni contact publiés par la source.",
        ),
        FicheOsm(
            "DF-TH-0024", "Cheikh Issa Diene", "tivaouane", "node", 4409568453, 14.9560817, -16.8157492,
            "Thi\u00e8s", "Tivaouane", "Tivaouane", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Tivaouane. Ni horaire ni contact publiés par la source.",
        ),
        FicheOsm(
            "DF-TH-0025", "Le Prokhane", "tivaouane", "node", 4409568455, 14.9559145, -16.8160108,
            "Thi\u00e8s", "Tivaouane", "Tivaouane", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Tivaouane. Ni horaire ni contact publiés par la source.",
        ),
        FicheOsm(
            "DF-TH-0026", "chez amadou maiga", "tivaouane", "node", 4409568461, 14.9567373, -16.8145181,
            "Thi\u00e8s", "Tivaouane", "Tivaouane", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Tivaouane. Ni horaire ni contact publiés par la source.",
        ),
        FicheOsm(
            "DF-TH-0027", "Le Virage", "tivaouane", "node", 4410158909, 14.9554770, -16.8170108,
            "Thi\u00e8s", "Tivaouane", "Tivaouane", "fast_food", [],
            "Fast-food référencé sur OpenStreetMap à Tivaouane. Ni horaire ni contact publiés par la source.",
        ),
        FicheOsm(
            "DF-TH-0028", "complexe dabakh", "tivaouane", "node", 4413287301, 14.9397943, -16.8286027,
            "Thi\u00e8s", "Tivaouane", "Tivaouane", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Tivaouane. Ni horaire ni contact publiés par la source.",
        ),
        FicheOsm(
            "DF-LG-0006", "L'Endroit idéal", "kebemer", "node", 5379038058, 15.3666067, -16.4528391,
            "Louga", "K\u00e9b\u00e9mer", "K\u00e9b\u00e9mer", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Kébémer. Ni horaire ni contact publiés par la source.",
        ),
        FicheOsm(
            "DF-LG-0007", "Restaurant le Cayor", "kebemer", "way", 1187858308, 15.3744449, -16.4492625,
            "Louga", "K\u00e9b\u00e9mer", "K\u00e9b\u00e9mer", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Kébémer. Ni horaire ni contact publiés par la source.",
        ),
        # ------------------------------------------------- Bignona (Ziguinchor)
        FicheOsm(
            "DF-ZG-0009", "Complexe MaBelle Service", "bignona", "way", 202732567, 12.8036309, -16.2275889,
            "Ziguinchor", "Bignona", "Bignona", "restaurant", ['senegalaise'],
            "Restaurant référencé sur OpenStreetMap à Bignona ; la source le classe en cuisine régionale et "
            "déclare un accès fauteuil roulant praticable, une zone fumeurs et un accès internet payant "
            "(tags déclaratifs, non confirmés). Relevé initial de la source : « bing ».",
        ),
        FicheOsm(
            "DF-ZG-0010", "Restaurant Adji Ngom", "bignona", "way", 202738017, 12.7987102, -16.2254061,
            "Ziguinchor", "Bignona", "Bignona", "restaurant", ['senegalaise'],
            "Restaurant référencé sur OpenStreetMap à Bignona (cuisine régionale selon la source). La "
            "source déclare une appréciation « 3 étoiles », un accès fauteuil roulant praticable et une "
            "zone fumeurs : appréciation déclarative, non contrôlée par DEKK FOOD.",
        ),
        # ---------------------------- Cap Skirring / Kabrousse (relevé Overpass 2026-10-13)
        FicheOsm(
            "DF-ZG-0011", "Sun Cafe", "cap-skirring", "node", 5300760963, 12.4276278, -16.6660012,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap au nord de Cap Skirring. La source ne publie ni horaire ni contact.",
        ),
        FicheOsm(
            "DF-ZG-0012", "L'acacia, chez Fatou", "cap-skirring", "node", 5492878126, 12.3866479, -16.7364388,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Cap Skirring. La source ne publie ni horaire ni contact.",
        ),
        FicheOsm(
            "DF-ZG-0013", "Carpe Rouge", "cap-skirring", "node", 5492878323, 12.3870554, -16.7380773,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Cap Skirring. La source ne publie ni horaire ni contact.",
        ),
        FicheOsm(
            "DF-ZG-0014", "Les Palmiers", "cap-skirring", "node", 5558705022, 12.3869255, -16.7393618,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Cap Skirring. La source ne publie ni horaire ni contact.",
        ),
        FicheOsm(
            "DF-ZG-0015", "casa pizzeria", "cap-skirring", "node", 6297514397, 12.3854044, -16.7358599,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "pizzeria", ['pizza'],
            "Pizzeria référencée sur OpenStreetMap à Cap Skirring. Un site web est indiqué par la source ; il n'a pas été ouvert ni contrôlé par DEKK FOOD.",
            site_web="https://www.cap-skirring.voyage/pizzeria-cap-skirring-casa-pizza.html",
        ),
        FicheOsm(
            "DF-ZG-0016", "Chez loulou", "cap-skirring", "node", 6299909316, 12.3712665, -16.7268051,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", ['pizza'],
            "Restaurant référencé sur OpenStreetMap rue de Kabrousse (Cap Skirring) ; la source le classe en pizza. Téléphone publié par la source, non appelé par DEKK FOOD.",
            adresse_complete="Rue de Kabrousse, Cap Skirring",
            telephone="78 432 74 93",
        ),
        FicheOsm(
            "DF-ZG-0017", "Case Bambou", "cap-skirring", "node", 7027861085, 12.3875150, -16.7382638,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Cap Skirring. Téléphone publié par la source, non appelé par DEKK FOOD.",
            telephone="+221 77 547 91 26",
        ),
        FicheOsm(
            "DF-ZG-0018", "La petite Suisse", "cap-skirring", "node", 9707035057, 12.3719604, -16.7319171,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Cap Skirring ; la fiche source porte une date de contrôle communautaire (check_date 2025-02-28) qui ne vaut pas vérification par DEKK FOOD.",
        ),
        FicheOsm(
            "DF-ZG-0019", "cap7 restauration", "cap-skirring", "node", 10287666409, 12.3886128, -16.7479818,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Cap Skirring. La source ne publie ni horaire ni contact.",
        ),
        FicheOsm(
            "DF-ZG-0020", "Mussuwam", "cap-skirring", "node", 10709189044, 12.3733060, -16.7321697,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", ['senegalaise'],
            "Restaurant référencé sur OpenStreetMap à Cap Skirring (cuisine régionale selon la source, contrôle communautaire daté du 2025-02-28). Ni le téléphone ni le site web publiés par la source n'ont été vérifiés : le numéro indiqué comporte un nombre de chiffres inhabituel, il reste à confirmer.",
        ),
        FicheOsm(
            "DF-ZG-0021", "Filaos", "cap-skirring", "node", 12625727296, 12.3521544, -16.7263982,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", ['fruits_de_mer'],
            "Restaurant référencé sur OpenStreetMap vers Kabrousse ; la source le classe en poisson. Accès fauteuil roulant déclaré non praticable (tag déclaratif).",
        ),
        FicheOsm(
            "DF-ZG-0022", "Bar de la mer", "cap-skirring", "node", 12625732210, 12.3498297, -16.7244241,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Établissement référencé sur OpenStreetMap vers Kabrousse (bar-restaurant). Accès fauteuil roulant déclaré non praticable (tag déclaratif).",
        ),
        FicheOsm(
            "DF-ZG-0023", "Le Diamota - bar restaurant", "cap-skirring", "node", 12626031429, 12.3543897, -16.7284188,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Bar-restaurant référencé sur OpenStreetMap vers Kabrousse ; ouverture déclarative Mo-Su 09:00-22:00 (non confirmée) et téléphone publié par la source, non appelé par DEKK FOOD.",
            telephone="+221 77 657 55 09",
        ),
        FicheOsm(
            "DF-ZG-0024", "Soleil", "cap-skirring", "node", 12626083113, 12.3582705, -16.7298521,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap vers Kabrousse. La source ne publie ni horaire ni contact.",
        ),
        FicheOsm(
            "DF-ZG-0025", "Chez Barlo et Mina - bar restaurant", "cap-skirring", "node", 12626097463, 12.3665884, -16.7306921,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Bar-restaurant référencé sur OpenStreetMap vers Kabrousse. Téléphone publié par la source, non appelé par DEKK FOOD.",
            telephone="+221774077326",
        ),
        FicheOsm(
            "DF-ZG-0026", "Kassumay", "cap-skirring", "node", 12626105420, 12.3722286, -16.7320595,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Cap Skirring. Téléphone publié par la source, non appelé par DEKK FOOD.",
            telephone="+221774036265",
        ),
        FicheOsm(
            "DF-ZG-0027", "Burette No stress", "cap-skirring", "node", 12626109868, 12.3719935, -16.7321015,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Cap Skirring. La source ne publie ni horaire ni contact.",
        ),
        FicheOsm(
            "DF-ZG-0028", "Boudody", "cap-skirring", "node", 12630031286, 12.3685630, -16.7308137,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Cap Skirring. Téléphone publié par la source, non appelé par DEKK FOOD.",
            telephone="+221775449752",
        ),
        FicheOsm(
            "DF-ZG-0029", "Africabane", "cap-skirring", "node", 12630098151, 12.3749759, -16.7332617,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Cap Skirring. La source ne publie ni horaire ni contact.",
        ),
        FicheOsm(
            "DF-ZG-0030", "Le paillotin", "cap-skirring", "node", 12630379459, 12.3759571, -16.7335245,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", ['street_food'],
            "Restaurant référencé sur OpenStreetMap à Cap Skirring ; la source mentionne salades et brochettes.",
        ),
        FicheOsm(
            "DF-ZG-0031", "Kaye-FI", "cap-skirring", "node", 12635790425, 12.3488321, -16.7235005,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap vers Kabrousse. Téléphone publié par la source, non appelé par DEKK FOOD ; la fiche source renvoie aussi vers une photo Wikimedia Commons (non reprise ici).",
            telephone="+22177 773 07 72",
        ),
        FicheOsm(
            "DF-ZG-0032", "Le Régal", "cap-skirring", "node", 12766745546, 12.3864734, -16.7369784,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Cap Skirring. Téléphone publié par la source, non appelé par DEKK FOOD.",
            telephone="+221 77 506 57 88",
        ),
        FicheOsm(
            "DF-ZG-0033", "Le petit gourmet", "cap-skirring", "node", 12766745553, 12.3853345, -16.7359807,
            "Ziguinchor", "Oussouye", "Diemb\u00e9ring", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Cap Skirring. La source ne publie ni horaire ni contact.",
        ),
        # --------------------------------------------------- Sokone (Fatick)
        FicheOsm(
            "DF-FK-0003", "Jokkoo", "sokone", "node", 4985311436, 13.8842123, -16.3715018,
            "Fatick", "Foundiougne", "Sokone", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Sokone. La source ne publie ni horaire ni contact.",
        ),
        FicheOsm(
            "DF-FK-0004", "Auberge Restaurant Le Cailcedrat", "sokone", "node", 13477136101, 13.8860018, -16.3717177,
            "Fatick", "Foundiougne", "Sokone", "restaurant_hotel", [],
            "Auberge-restaurant référencée sur OpenStreetMap à Sokone ; la source déclare un accès Wi-Fi "
            "(tag internet_access=wlan, déclaratif) et un téléphone, non appelé par DEKK FOOD.",
            telephone="774305204",
        ),
        # ---------------------------------------------------------- Kédougou
        FicheOsm(
            "DF-KE-0001", "Restaurant Le Carrefour", "kedougou", "node", 6342092186, 12.5552069, -12.1806154,
            "Kédougou", "Kédougou", "Kédougou", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap au centre de Kédougou.",
            adresse_complete="Kédougou", quartier="Centre",
        ),
        # ----------------------------------------------------------- Sédhiou
        FicheOsm(
            "DF-SE-0001", "Chez Maty", "sedhiou", "node", 4600534190, 12.7091364, -15.5583737,
            "Sédhiou", "Sédhiou", "Sédhiou", "restaurant", [],
            "Restaurant référencé sur OpenStreetMap à Sédhiou. Aucun contact n'est publié par la source ; "
            "le numéro de téléphone sera ajouté après vérification.",
            adresse_complete="Sédhiou", quartier="Centre",
        ),
    ]

    contenu = {
        "version": 1,
        "date_collecte": DATE,
        "origine": "openstreetmap",
        "description": (
            "Établissements relevés dans la base cartographique publique OpenStreetMap via l'API "
            "Overpass le 2026-10-13 (licence ODbL). Cette source permet de couvrir les régions "
            "ignorées des annuaires grand public et de disposer de coordonnées publiées, "
            "mais ces coordonnées restent communautaires : elles ne valent pas vérification sur place."
        ),
        "regles": [
            "Attribution ODbL conservée : chaque fiche cite www.openstreetmap.org et l'identifiant du nœud.",
            "Coordonnées publiées mais gps_verifie = false : aucune position n'est certifiée.",
            "Les horaires OSM sont retranscrits tels quels et marqués confirme = false.",
            "Les noms d'établissements comportant un patronyme ne sont pas interprétés comme des propriétaires.",
        ],
        "etablissements": [fiche.as_dict() for fiche in fiches],
    }
    sortie = Path("data/seed/2026-10-13_sources_openstreetmap.json")
    sortie.write_text(json.dumps(contenu, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(fiches)} fiches écrites dans {sortie}")


if __name__ == "__main__":
    main()
