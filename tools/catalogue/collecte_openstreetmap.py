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
            adresse_complete="Richard-Toll", quartier="Centre",
        ),
        FicheOsm(
            "DF-SL-0008", "Burger City", "richard-toll", "node", 9085129867, 16.4670861, -15.7034560,
            "Saint-Louis", "Dagana", "Richard-Toll", "fast_food", ["burgers", "street_food"],
            "Fast-food référencé sur OpenStreetMap à Richard-Toll.",
            adresse_complete="Richard-Toll", quartier="Centre",
        ),
        FicheOsm(
            "DF-SL-0009", "Le Walo", "richard-toll", "node", 12738922213, 16.4678299, -15.7067277,
            "Saint-Louis", "Dagana", "Richard-Toll", "fast_food", ["senegalaise", "grillades"],
            "Établissement référencé sur OpenStreetMap à Richard-Toll : « plat du jour et dibi » "
            "(mention publiée par la source).",
            adresse_complete="Richard-Toll", quartier="Centre",
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
