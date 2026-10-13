"""Deuxième vague de collecte depuis les annuaires publics (senefinder, senlocal).

Ce script documente EXACTEMENT les données relevées le 2026-10-13 dans les
pages publiques des annuaires, et les écrit au format de collecte
(`data/seed/2026-10-13_sources_annuaires_2.json`).

Règles appliquées :
- aucune donnée n'est inventée : un champ absent de la page source reste absent ;
- les contacts relevés ne sont jamais marqués « confirmés » (ils ne le sont pas
  par la source) ;
- le niveau de vérification distingue les fiches dotées du badge « Vérifié » de
  l'annuaire (partiellement_verifie) des fiches sans contrôle annoncé (a_confirmer).

Usage : python3 tools/catalogue/collecte_annuaires_2.py
"""

from __future__ import annotations

import json
from pathlib import Path

DATE = "2026-10-13"
SENEFINDER = "senefinder"
SENLOCAL = "senlocal"


class Fiche:
    def __init__(
        self,
        numero: str,
        nom: str,
        ville_slug: str,
        type_etablissement: str,
        categories: list[str],
        adresse: dict,
        contacts: list[dict],
        description: str,
        source: str,
        source_url: str,
        niveau: str = "a_confirmer",
        services: list[str] | None = None,
    ) -> None:
        self.numero = numero
        self.nom = nom
        self.ville_slug = ville_slug
        self.type_etablissement = type_etablissement
        self.categories = categories
        self.adresse = adresse
        self.contacts = contacts
        self.description = description
        self.source = source
        self.source_url = source_url
        self.niveau = niveau
        self.services = services or []

    def as_dict(self) -> dict:
        return {
            "cle": f"{self.source}:{self.source_url.rsplit('/', 1)[-1]}",
            "numero_fiche": self.numero,
            "nom": self.nom,
            "slug": _slug(self.nom, self.ville_slug),
            "type_etablissement": self.type_etablissement,
            "categories": self.categories,
            "description_courte": self.description,
            "statut": "a_verifier",
            "niveau_verification": self.niveau,
            "adresse": self.adresse,
            "contacts": [
                {
                    "type": contact["type"],
                    "valeur": contact["valeur"],
                    "confirme": False,
                    "source": self.source,
                    "source_url": self.source_url,
                }
                for contact in self.contacts
            ],
            "services": self.services,
            "images": [],
            "menus": [],
            "sources": [
                {
                    "source": self.source,
                    "url": self.source_url,
                    "date_collecte": DATE,
                    "donnees": "nom, adresse"
                    + (", telephone" if any(c["type"] == "telephone" for c in self.contacts) else "")
                    + (", whatsapp" if any(c["type"] == "whatsapp" for c in self.contacts) else ""),
                    "niveau_confiance": "moyen" if self.niveau == "partiellement_verifie" else "faible",
                }
            ],
            "date_collecte": DATE,
            "origine_donnee": self.source,
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


def _adresse(region, departement, commune, quartier, complete) -> dict:
    return {
        "region": region,
        "departement": departement,
        "commune": commune,
        "quartier_libre": quartier,
        "adresse_complete": complete,
        "latitude": None,
        "longitude": None,
        "gps_verifie": False,
    }


def _tel(valeur: str) -> dict:
    return {"type": "telephone", "valeur": valeur}


def _wa(valeur: str) -> dict:
    return {"type": "whatsapp", "valeur": valeur}


S = "https://senefinder.com/fr/business/"
L = "https://senlocal.com/entreprises/"

FICHES: list[Fiche] = [
    # ------------------------------------------------------------------ Dakar
    Fiche("DF-DK-0034", "L'Endroit", "dakar", "restaurant", [], _adresse("Dakar", "Dakar", "Dakar Plateau", "Dakar", "Dakar"), [_tel("+221338246425")],
          "Adresse relevée dans l'annuaire Senefinder (ville de Dakar) ; type d'établissement non précisé par la source.",
          SENEFINDER, S + "food-lendroit-dakar-uy4m"),
    Fiche("DF-DK-0035", "La Traditionnelle", "dakar", "restaurant", ["senegalaise"], _adresse("Dakar", "Dakar", "Dakar Plateau", "Plateau", "Rue Felix Faure, Dakar"), [_tel("+221338229292")],
          "Restaurant référencé rue Félix Faure à Dakar (annuaire Senefinder) ; catégorie déduite du libellé de l'annonce.",
          SENEFINDER, S + "food-la-traditionnelle-dakar-t5d0"),
    Fiche("DF-DK-0036", "SAPPHIRE restaurant Dakar", "dakar", "restaurant", ["internationale"], _adresse("Dakar", "Dakar", "Dakar Plateau", "Plateau", "Villa N, 1 Boulevard du Président Habib Bourguiba, Dakar"), [_wa("+221784422424")],
          "Restaurant référencé sur le boulevard du Président Habib Bourguiba (annuaire Senefinder).",
          SENEFINDER, S + "food-sapphire-restaurant-dakar-dakar-7ly6"),
    Fiche("DF-DK-0037", "Pur Délice Dakar", "dakar", "patisserie", ["patisserie_dessert"], _adresse("Dakar", "Dakar", "Dakar Plateau", "Plateau", "62 Rue Felix Faure, Dakar"), [_wa("+221784321414")],
          "Pâtisserie référencée rue Félix Faure (annuaire Senefinder).",
          SENEFINDER, S + "food-pur-delice-dakar-dakar-qytk"),
    Fiche("DF-DK-0038", "Aroma Gelato vdn", "dakar", "glacier", ["patisserie_dessert"], _adresse("Dakar", "Dakar", "Grand Yoff", "Amitié 3", "Amitié 3 VDN, villa 4436, Dakar"), [_tel("+221338258081")],
          "Glacier référencé à l'Amitié 3 (VDN) par l'annuaire Senefinder.",
          SENEFINDER, S + "food-aroma-gelato-vdn-dakar-prgv"),
    Fiche("DF-DK-0039", "Boulangerie Mbacké", "dakar", "boulangerie", ["patisserie_dessert", "petit_dejeuner"], _adresse("Dakar", "Dakar", "Grand Yoff", "Unité 03", "Unité 03, Dakar"), [_wa("+221784662438")],
          "Boulangerie référencée par l'annuaire Senefinder (quartier « unité 03 »).",
          SENEFINDER, S + "food-boulangerie-mbacke-dakar-m8x9"),
    Fiche("DF-DK-0040", "Al Manara Sea food", "dakar", "restaurant", ["fruits_de_mer", "grillades"], _adresse("Dakar", "Dakar", "Ouakam", "Mamelles Aviation", "Ouakam, Mamelles Aviation, Dakar"), [_wa("+221772465050")],
          "Restaurant de fruits de mer référencé à Ouakam/Mamelles (annuaire Senefinder).",
          SENEFINDER, S + "food-al-manara-sea-food-dakar-sy93"),
    Fiche("DF-DK-0041", "Chez Madame Biaye", "dakar", "gargote", [], _adresse("Dakar", "Dakar", "Grand Yoff", "LIB 222", "674 Rue LIB 222, Dakar"), [_wa("+221774198634")],
          "Établissement de restauration référencé rue LIB 222 (annuaire Senefinder) ; type exact non documenté par la source.",
          SENEFINDER, S + "food-chez-madame-biaye-dakar-h90o"),
    Fiche("DF-DK-0042", "Al Marinas", "dakar", "restaurant", [], _adresse("Dakar", "Dakar", "Hann Bel-Air", "Hann Bel-Air", "Hann Bel-Air, Dakar"), [_wa("+221775521634")],
          "Établissement de restauration référencé à Hann Bel-Air (annuaire Senefinder).",
          SENEFINDER, S + "food-al-marinas-dakar-ryvt"),
    Fiche("DF-DK-0043", "AS SALAM", "dakar", "restaurant", [], _adresse("Dakar", "Dakar", "Dakar Plateau", "Plateau", "15 Rue Mass Diokhané, Dakar"), [_tel("+221338239808")],
          "Établissement de restauration référencé rue Mass Diokhané (annuaire Senefinder).",
          SENEFINDER, S + "food-as-salam-dakar-prnt"),
    Fiche("DF-DK-0044", "African Food Restaurant", "dakar", "restaurant", ["africaine"], _adresse("Dakar", "Dakar", "Grand Yoff", "Dieuppeul Derklé", "Dieuppeul Derklé, Dakar"), [_wa("+221777554091")],
          "Restaurant de cuisine africaine référencé à Dieuppeul Derklé (annuaire Senefinder).",
          SENEFINDER, S + "food-african-food-restaurant-dakar-zfo6"),
    Fiche("DF-DK-0045", "Al Mahdi", "dakar", "restaurant", [], _adresse("Dakar", "Dakar", "Yoff", "Yoff", "Yoff, Dakar"), [_tel("+221338205889")],
          "Établissement de restauration référencé à Yoff (annuaire Senefinder).",
          SENEFINDER, S + "food-al-mahdi-dakar-eyma"),
    Fiche("DF-DK-0046", "Alftone Senegal", "dakar", "restaurant", [], _adresse("Dakar", "Dakar", "Grand Yoff", "Sipres", "91 rond-point Sipres VD, Dakar"), [],
          "Établissement référencé par l'annuaire Senefinder ; aucun contact publié par la source.",
          SENEFINDER, S + "food-alftone-senegal-dakar-3fdz"),
    Fiche("DF-DK-0047", "Chez Papa", "dakar", "restaurant", [], _adresse("Dakar", "Dakar", "Dakar Plateau", "Médina", "x 17, Rue 6, Dakar"), [_wa("+221785424001")],
          "Établissement de restauration référencé rue 6 (annuaire Senefinder).",
          SENEFINDER, S + "food-chez-papa-dakar-tjnw"),
    Fiche("DF-DK-0048", "La Brioche Dorée Bourguiba", "dakar", "boulangerie", ["patisserie_dessert", "petit_dejeuner"], _adresse("Dakar", "Dakar", "Dakar Plateau", "Plateau", "1530 Rue LIB 226, Dakar"), [_tel("+221338241438")],
          "Enseigne de boulangerie-pâtisserie référencée boulevard Bourguiba (annuaire Senefinder).",
          SENEFINDER, S + "food-la-brioche-doree-bourguiba-dakar-to0c"),
    Fiche("DF-DK-0049", "Artisan Boulanger Eric Kayser", "dakar", "boulangerie", ["patisserie_dessert", "petit_dejeuner"], _adresse("Dakar", "Dakar", "Dakar Plateau", "Plateau", "3 Boulevard de la République, Dakar"), [_tel("+221338228180")],
          "Boulangerie référencée boulevard de la République (annuaire Senefinder).",
          SENEFINDER, S + "food-artisan-boulanger-eric-kayser-dakar-ybkk"),
    Fiche("DF-DK-0050", "Pâtisserie Fleur de Lys Ngor", "dakar", "patisserie", ["patisserie_dessert"], _adresse("Dakar", "Dakar", "Ngor", "Ngor", "104 Tally bou Bess, Dakar"), [_wa("+221777218698")],
          "Pâtisserie référencée à Ngor (annuaire Senefinder).",
          SENEFINDER, S + "food-patisserie-fleur-de-lys-ngor-dakar-hlkk"),
    Fiche("DF-DK-0051", "Nostos Africa Boulangerie et Pâtisserie par Karima", "dakar", "boulangerie", ["patisserie_dessert"], _adresse("Dakar", "Dakar", "Grand Yoff", "OKM", "1158 Rue OKM 188, Dakar"), [_wa("+221781501196")],
          "Boulangerie-pâtisserie référencée rue OKM 188 (annuaire Senefinder). Le nom du gérant n'est pas repris ici : « par Karima » figure dans l'annonce publique mais n'identifie pas une personne documentée comme propriétaire.",
          SENEFINDER, S + "food-nostos-africa-boulangerie-et-patisserie-par-karima-dakar-th6x"),
    Fiche("DF-DK-0052", "SOBO", "dakar", "restaurant", [], _adresse("Dakar", "Dakar", "Dakar Plateau", "Plateau", "Rond-point JVC, Dakar"), [_wa("+221781757878")],
          "Établissement de restauration référencé au rond-point JVC (annuaire Senefinder).",
          SENEFINDER, S + "food-sobo-dakar-yfom"),
    Fiche("DF-DK-0053", "Maison Kayser (Éric Kayser)", "dakar", "boulangerie", ["patisserie_dessert", "petit_dejeuner"], _adresse("Dakar", "Dakar", "Dakar Plateau", "Plateau", "Rue de l'Université, Dakar"), [_wa("+221785980010")],
          "Boulangerie-pâtisserie référencée rue de l'Université (annuaire Senefinder).",
          SENEFINDER, S + "food-maison-kayser-eric-kayser-dakar-aniy"),
    Fiche("DF-DK-0054", "Little Delight", "dakar", "restaurant", [], _adresse("Dakar", "Dakar", "Fann-Point E-Amitié", "Point E", "4 avenue Birago Diop, Dakar"), [_wa("+221789234348")],
          "Établissement de restauration référencé avenue Birago Diop (annuaire Senefinder).",
          SENEFINDER, S + "food-little-delight-dakar-gm06"),
    Fiche("DF-DK-0055", "Kotao Coffee Almadies", "dakar", "cafe_restaurant", ["brunch", "internationale"], _adresse("Dakar", "Dakar", "Ngor", "Almadies", "Route de King Fahd, Méridien, Dakar"), [_wa("+221777187652")],
          "Café-restaurant référencé sur la route de King Fahd (annuaire Senefinder).",
          SENEFINDER, S + "food-kotao-coffee-almadies-dakar-liyt"),
    Fiche("DF-DK-0056", "Fast Food Touba Sandaga", "dakar", "fast_food", ["street_food", "senegalaise"], _adresse("Dakar", "Dakar", "Dakar Plateau", "Lamine Guèye", "Lamine Guèye, Dakar"), [_wa("+221785366905")],
          "Fast-food référencé au quartier Lamine Guèye (annuaire Senefinder).",
          SENEFINDER, S + "food-fast-food-touba-sandaga-dakar-iwph"),
    # --------------------------------------------------- Rufisque (région Dakar)
    Fiche("DF-DK-0057", "Les délices de bousso", "rufisque", "patisserie", ["patisserie_dessert"], _adresse("Dakar", "Rufisque", "Rufisque Est", "Santé Yalla", "Santé Yalla, Rufisque"), [_wa("+221775963680")],
          "Pâtisserie référencée à Rufisque (annuaire Senefinder).",
          SENEFINDER, S + "food-les-delices-de-bousso-rufisque-sfah"),
    Fiche("DF-DK-0058", "O' Bon Coin", "rufisque", "restaurant", [], _adresse("Dakar", "Rufisque", "Rufisque Est", "Layousse", "Ancienne route des Entrepôts Layousse x Keur Diop Bukki, Rufisque"), [_wa("+221785474141")],
          "Établissement de restauration référencé à Rufisque (annuaire Senefinder).",
          SENEFINDER, S + "food-o-bon-coin-rufisque-vjwl"),
    Fiche("DF-DK-0059", "Restaurant RIO TERANGA", "rufisque", "restaurant", ["senegalaise"], _adresse("Dakar", "Rufisque", "Rufisque Est", "Keury Kao", "Immeuble Diagne Faye, rue Ousmane Socé Diop, Rufisque"), [_wa("+221772403407")],
          "Restaurant référencé à Rufisque (Keury Kao) par l'annuaire Senefinder.",
          SENEFINDER, S + "food-restaurant-rio-teranga-rufisque-wn4l"),
    # ------------------------------------------------------------------ Thiès
    Fiche("DF-TH-0011", "OBS Resto Chicha", "thies", "restaurant", [], _adresse("Thiès", "Thiès", "Thiès Nord", "Escale", "Rue Dr Birane Beye, Thiès"), [_wa("+221784269172")],
          "Établissement de restauration référencé à Thiès (annuaire Senefinder).",
          SENEFINDER, S + "food-obs-resto-chicha-thies-nrun"),
    Fiche("DF-TH-0012", "La Brioche Dorée Mbour", "mbour", "boulangerie", ["patisserie_dessert", "petit_dejeuner"], _adresse("Thiès", "Mbour", "Mbour", "Centre", "Mbour"), [_tel("+221339575353")],
          "Enseigne de boulangerie-pâtisserie référencée à Mbour (annuaire Senefinder).",
          SENEFINDER, S + "food-la-brioche-doree-mbour-mbour-lne2"),
    Fiche("DF-TH-0013", "Touky Lounge The RoofTop", "saly", "restaurant_rooftop", ["internationale", "grillades"], _adresse("Thiès", "Mbour", "Saly Portudal", "Saly Niakh Niakhal", "Saly Niakh Niakhal, Saly"), [],
          "Rooftop-lounge de Saly Niakh Niakhal référencé par Senlocal (fiche avec badge « Vérifié » de l'annuaire ; aucun contrôle sur place par DEKK FOOD).",
          SENLOCAL, L + "touky-lounge-the-rooftop", niveau="partiellement_verifie", services=["terrasse", "vue_mer"]),
    Fiche("DF-TH-0014", "Salimtoo Cuisinotèque Sénégalaise", "ngaparou", "restaurant", ["senegalaise"], _adresse("Thiès", "Mbour", "Ngaparou", "Ngaparou", "Ngaparou"), [_wa("+221774596725")],
          "Restaurant référencé à Ngaparou (annuaire Senefinder, annonce récente au 2026-10-13).",
          SENEFINDER, S + "food-salimtoo-cuisinoteque-senegalaise-ngaparou-yab5"),
    # ------------------------------------------------------------- Saint-Louis
    Fiche("DF-SL-0001", "Boulanger Ndar Gueth", "saint-louis", "boulangerie", ["patisserie_dessert", "petit_dejeuner"], _adresse("Saint-Louis", "Saint-Louis", "Saint-Louis", "Saint-Louis", "Saint-Louis"), [_wa("+221779610099")],
          "Boulangerie référencée à Saint-Louis (annuaire Senefinder, annonce récente au 2026-10-13).",
          SENEFINDER, S + "food-boulanger-ndar-gueth-saint-louis-6y24"),
    Fiche("DF-SL-0002", "La Saigonnaise", "saint-louis", "restaurant", ["asiatique"], _adresse("Saint-Louis", "Saint-Louis", "Saint-Louis", "Saint-Louis", "Saint-Louis"), [_tel("+221339616481")],
          "Restaurant référencé à Saint-Louis (annuaire Senefinder) ; cuisine indiquée par le nom de l'enseigne, à confirmer.",
          SENEFINDER, S + "food-la-saigonnaise-saint-louis-onhs"),
    Fiche("DF-SL-0003", "Aux Délices du fleuve", "saint-louis", "patisserie", ["patisserie_dessert"], _adresse("Saint-Louis", "Saint-Louis", "Saint-Louis", "Saint-Louis", "155 Rue Blanchot, Saint-Louis"), [_tel("+221339614251")],
          "Pâtisserie référencée 155 rue Blanchot à Saint-Louis (annuaire Senefinder).",
          SENEFINDER, S + "food-aux-delices-du-fleuve-saint-louis-afpp"),
    Fiche("DF-SL-0004", "Farmers Coffee Shop Saint-Louis Sénégal", "saint-louis", "cafe_restaurant", ["petit_dejeuner", "brunch"], _adresse("Saint-Louis", "Saint-Louis", "Saint-Louis", "Saint-Louis", "441 avenue Blaise Diagne, Saint-Louis"), [_wa("+221772275084")],
          "Café référencé avenue Blaise Diagne à Saint-Louis (annuaire Senefinder).",
          SENEFINDER, S + "food-farmers-coffee-shop-saint-louis-senegal-saint-louis-uzwx"),
    Fiche("DF-SL-0005", "Coconut cafe", "saint-louis", "cafe_restaurant", ["petit_dejeuner"], _adresse("Saint-Louis", "Saint-Louis", "Saint-Louis", "Saint-Louis", "445 Rue Bisson, Saint-Louis"), [_wa("+221774665554")],
          "Café référencé rue Bisson à Saint-Louis (annuaire Senefinder).",
          SENEFINDER, S + "food-coconut-cafe-saint-louis-qos0"),
    Fiche("DF-SL-0006", "Restaurant Saharaoui", "saint-louis", "complexe_restauration", ["senegalaise", "pizza", "street_food", "patisserie_dessert"], _adresse("Saint-Louis", "Saint-Louis", "Saint-Louis", "Quartier Nord", "Quartier Nord, Saint-Louis"), [_tel("+221774221175")],
          "Établissement multi-format (restaurant, pâtisserie, pizzeria, fast-food, glacier) du quartier Nord de Saint-Louis, référencé par Senlocal avec badge « Vérifié » de l'annuaire.",
          SENLOCAL, L + "restaurant-saharaoui-saint-louis", niveau="partiellement_verifie"),
    # ------------------------------------------------------------------ Kaolack
    Fiche("DF-KL-0001", "Pâtisserie Diadiouba Fast-Food", "kaolack", "fast_food", ["patisserie_dessert", "street_food"], _adresse("Kaolack", "Kaolack", "Kaolack", "Kaolack", "Rue des Écoles, Kaolack"), [_wa("+221781568490")],
          "Pâtisserie / fast-food référencé rue des Écoles à Kaolack (annuaire Senefinder).",
          SENEFINDER, S + "food-patisserie-diadiouba-fast-food-kaolack-twdr"),
    Fiche("DF-KL-0002", "Restaurant LA PALASSE", "kaolack", "restaurant", [], _adresse("Kaolack", "Kaolack", "Kaolack", "Kaolack", "En face de l'aérodrome, sur la nationale, Kaolack"), [_wa("+221776141144")],
          "Restaurant référencé en face de l'aérodrome de Kaolack (annuaire Senefinder).",
          SENEFINDER, S + "food-restaurant-la-palasse-kaolack-d2sy"),
    Fiche("DF-KL-0003", "Restaurant Blue Bird", "kaolack", "restaurant", ["senegalaise", "internationale"], _adresse("Kaolack", "Kaolack", "Kaolack", "Kaolack", "Kaolack"), [_tel("+221339415350")],
          "Restaurant de Kaolack (cuisine sénégalaise, européenne et moyen-orientale) référencé par Senlocal avec badge « Vérifié » de l'annuaire.",
          SENLOCAL, L + "restaurant-blue-bird-kaolack", niveau="partiellement_verifie"),
    Fiche("DF-KL-0004", "La Kaolackoise Restaurant Traiteur", "kaolack", "traiteur", ["africaine"], _adresse("Kaolack", "Kaolack", "Kaolack", "Kaolack", "Kaolack"), [_tel("+221776596526")],
          "Restaurant et traiteur de Kaolack référencé par Senlocal avec badge « Vérifié » de l'annuaire (mariages, événements d'entreprise).",
          SENLOCAL, L + "la-kaolackoise-restaurant-traiteur", niveau="partiellement_verifie", services=["traiteur"]),
    # ------------------------------------------------------------------ Touba
    Fiche("DF-DB-0004", "Resto Savours", "touba", "restaurant", [], _adresse("Diourbel", "Mbacké", "Touba Mosquée", "Touba", "Rond-point Envie FM, route Pharmacie, Touba"), [_wa("+221772530207")],
          "Restaurant référencé à Touba (annuaire Senefinder).",
          SENEFINDER, S + "food-resto-savours-touba-nakn"),
    # -------------------------------------------------------------- Ziguinchor
    Fiche("DF-ZG-0006", "Kagouleme Resto", "ziguinchor", "restaurant", ["fruits_de_mer", "grillades"], _adresse("Ziguinchor", "Ziguinchor", "Ziguinchor", "Escale", "Escale, Ziguinchor"), [_tel("+221339917424")],
          "Restaurant du centre-ville de Ziguinchor (grillades, poissons, crevettes) référencé par Senlocal avec badge « Vérifié » de l'annuaire.",
          SENLOCAL, L + "kagouleme-resto", niveau="partiellement_verifie"),
    Fiche("DF-ZG-0007", "Bar Restaurant chez Parfait", "ziguinchor", "restaurant", [], _adresse("Ziguinchor", "Ziguinchor", "Ziguinchor", "Centre", "Rue du Général de Gaulle, Ziguinchor"), [_wa("+221779507733")],
          "Bar-restaurant référencé rue du Général de Gaulle à Ziguinchor (annuaire Senefinder).",
          SENEFINDER, S + "food-bar-restaurant-chez-parfait-ziguinchor-sbu2"),
    Fiche("DF-ZG-0008", "VITO LUNCH Restaurant de Ziguinchor", "ziguinchor", "restaurant", [], _adresse("Ziguinchor", "Ziguinchor", "Ziguinchor", "Aéroport", "Aéroport de Ziguinchor"), [_tel("+221339925908")],
          "Restaurant référencé à l'aéroport de Ziguinchor (annuaire Senefinder).",
          SENEFINDER, S + "food-vito-lunch-restaurant-de-ziguinchor-ziguinchor-zsdu"),
]


def main() -> None:
    sortie = Path("data/seed/2026-10-13_sources_annuaires_2.json")
    contenu = {
        "version": 1,
        "date_collecte": DATE,
        "origine": "annuaires_publics",
        "description": (
            "Deuxième vague de collecte depuis les annuaires publics Senefinder et Senlocal "
            "(pages de recherche publiques consultées le 2026-10-13, sans contournement de "
            "protection technique). Les contacts relevés ne sont pas marqués confirmés et aucun "
            "menu, prix ou horaire n'est repris lorsqu'il n'est pas publié par la source."
        ),
        "regles": [
            "Aucune donnée inventée : les champs absents de la source restent vides.",
            "Les numéros relevés sont enregistrés tels que publiés par l'annuaire (confirme = false).",
            "Les fiches portant le badge « Vérifié » de l'annuaire sont marquées partiellement_verifie.",
            "Les positions GPS ne sont pas publiées par ces annuaires : latitude/longitude restent nulles.",
        ],
        "etablissements": [fiche.as_dict() for fiche in FICHES],
    }
    sortie.write_text(json.dumps(contenu, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(FICHES)} fiches écrites dans {sortie}")


if __name__ == "__main__":
    main()
