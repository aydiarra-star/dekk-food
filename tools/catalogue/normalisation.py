"""Normalisation des données du catalogue DEKK FOOD.

Ces fonctions sont volontairement pures (aucune dépendance externe) afin d'être
testables sans base de données ni accès réseau.
"""

from __future__ import annotations

import re
import unicodedata
from typing import Any, Optional

# Emprise géographique du Sénégal (contrôle des coordonnées collectées).
SENEGAL_BBOX = {
    "lat_min": 12.0,
    "lat_max": 16.8,
    "lon_min": -17.8,
    "lon_max": -11.2,
}

INDICATIF_SENEGAL = "221"


def sans_accents(valeur: str) -> str:
    """Retire les accents d'une chaîne (É -> E, ï -> i)."""
    decompose = unicodedata.normalize("NFKD", valeur or "")
    return "".join(c for c in decompose if not unicodedata.combining(c))


def slugifier(valeur: str) -> str:
    """Transforme un nom en identifiant lisible : « Chez Fatou ! » -> « chez-fatou »."""
    base = sans_accents(valeur or "").lower()
    base = re.sub(r"[^a-z0-9]+", "-", base)
    return base.strip("-") or "etablissement"


def cle_comparaison(valeur: str) -> str:
    """Empreinte de comparaison : minuscules sans accents ni ponctuation."""
    base = sans_accents(valeur or "").lower()
    return re.sub(r"[^a-z0-9]+", "", base)


def normaliser_telephone(valeur: Any, indicatif_par_defaut: str = INDICATIF_SENEGAL) -> Optional[str]:
    """Normalise un numéro sénégalais au format +221XXXXXXXXX.

    Accepte « 33 821 53 22 », « +221338215322 », « 00221781234567 », « 771234567 ».
    Renvoie None si le numéro ne peut pas être interprété de façon fiable :
    on préfère une information manquante à une information inventée.
    """
    if valeur is None:
        return None
    chiffres = re.sub(r"[^0-9+]", "", str(valeur))
    if chiffres.startswith("+00"):
        chiffres = "+" + chiffres[3:]
    if chiffres.startswith("00"):
        chiffres = "+" + chiffres[2:]
    if chiffres.startswith("+"):
        chiffres = chiffres[1:]
    if not chiffres.isdigit():
        return None

    if chiffres.startswith(indicatif_par_defaut) and len(chiffres) == len(indicatif_par_defaut) + 9:
        numero = chiffres[len(indicatif_par_defaut):]
    elif len(chiffres) == 9:
        numero = chiffres
    else:
        return None

    if not (numero.startswith("3") or numero.startswith("7")):
        return None

    return f"+{indicatif_par_defaut}{numero}"


def normaliser_whatsapp(valeur: Any) -> Optional[str]:
    """Le WhatsApp sénégalais est un numéro mobile (7X)."""
    numero = normaliser_telephone(valeur)
    if numero is None:
        return None
    national = numero[len(INDICATIF_SENEGAL) + 1:]
    if not national.startswith("7"):
        return None
    return numero


def normaliser_prix(valeur: Any, devise_par_defaut: str = "XOF") -> tuple[Optional[float], str]:
    """Extrait un montant numérique. « 3 000 FCFA » -> (3000.0, 'XOF')."""
    if valeur is None or valeur == "":
        return None, devise_par_defaut

    if isinstance(valeur, (int, float)):
        return float(valeur), devise_par_defaut

    texte = str(valeur)
    devise = devise_par_defaut
    if re.search(r"F\s*CFA|XOF|FCFA", texte, re.IGNORECASE):
        devise = "XOF"
    elif re.search(r"\bEUR\b|€", texte, re.IGNORECASE):
        devise = "EUR"
    elif re.search(r"\bUSD\b|\$", texte, re.IGNORECASE):
        devise = "USD"

    nombres = re.findall(r"[0-9][0-9\s\u00a0.,]*", texte)
    if not nombres:
        return None, devise

    brut = nombres[0].replace("\u00a0", "").replace(" ", "")
    # 3.500 ou 3,500 signifient 3500 en notation sénégalaise.
    if re.fullmatch(r"\d{1,3}([.,]\d{3})+", brut):
        brut = re.sub(r"[.,]", "", brut)
    elif re.fullmatch(r"\d+[.,]\d{1,2}", brut):
        brut = brut.replace(",", ".")

    try:
        return float(brut), devise
    except ValueError:
        return None, devise


def normaliser_horaire(valeur: Any) -> Optional[str]:
    """« 19h30 », « 19:30 », « 7h » -> « 19:30 », « 19:30 », « 07:00 »."""
    if valeur is None:
        return None
    texte = str(valeur).strip().lower().replace("h", ":")
    correspondance = re.fullmatch(r"(\d{1,2})(?::(\d{2}))?", texte)
    if not correspondance:
        return None
    heures = int(correspondance.group(1))
    minutes = int(correspondance.group(2) or 0)
    if heures > 23 or minutes > 59:
        return None
    return f"{heures:02d}:{minutes:02d}"


def normaliser_url(valeur: Any) -> Optional[str]:
    """Ajoute le schéma https:// manquant et refuse les valeurs non exploitables."""
    if not valeur:
        return None
    texte = str(valeur).strip()
    if texte.lower() in {"non", "aucun", "n/a", "-", "aucune"}:
        return None
    if not texte.startswith(("http://", "https://")):
        texte = "https://" + texte.lstrip("/")
    return texte


def normaliser_email(valeur: Any) -> Optional[str]:
    if not valeur:
        return None
    texte = str(valeur).strip().lower()
    return texte if re.fullmatch(r"[^@\s]+@[^@\s]+\.[a-z]{2,}", texte) else None


def verifier_coordonnees(latitude: Any, longitude: Any) -> tuple[Optional[float], Optional[float]]:
    """Contrôle que les coordonnées sont valides ET dans l'emprise du Sénégal.

    Un géocodage approximatif hors du Sénégal est rejeté : mieux vaut pas de
    coordonnées qu'une position fausse.
    """
    try:
        lat = float(latitude) if latitude not in (None, "") else None
        lon = float(longitude) if longitude not in (None, "") else None
    except (TypeError, ValueError):
        return None, None

    if lat is None or lon is None:
        return None, None
    if not (SENEGAL_BBOX["lat_min"] <= lat <= SENEGAL_BBOX["lat_max"]):
        return None, None
    if not (SENEGAL_BBOX["lon_min"] <= lon <= SENEGAL_BBOX["lon_max"]):
        return None, None
    return round(lat, 6), round(lon, 6)


# Mots trop génériques pour distinguer deux établissements : « Restaurant Le Lagon »
# et « Restaurant La Douma » ne doivent pas être considérés comme proches.
MOTS_GENERIQUES = {
    "restaurant", "resto", "restauration", "hotel", "complexe", "chez", "maison", "snack",
    "bar", "cafe", "le", "la", "les", "l", "d", "de", "du", "des", "au", "aux", "et", "the",
    "ex", "residence", "espace", "salon", "table", "cantine", "grill", "grillades",
}


def mots_significatifs(valeur: str) -> set[str]:
    """Mots d'un nom qui portent réellement l'identité de l'établissement."""
    base = sans_accents(valeur or "").lower()
    mots = [mot for mot in re.split(r"[^a-z0-9]+", base) if mot]
    significatifs = {mot for mot in mots if mot not in MOTS_GENERIQUES and len(mot) > 2}
    # Les chiffres et lettres isolés restent utiles (« Lagon 1 », « Maison B »).
    if not significatifs:
        significatifs = {mot for mot in mots if mot not in MOTS_GENERIQUES}
    return significatifs


def similarite_bigrammes(a: str, b: str) -> float:
    """Coefficient de Dice sur les bigrammes distincts des clés de comparaison.

    Implémentation miroir de la fonction SQL `public.similarite_chaines` : les
    deux moteurs de déduplication (Python et PostgreSQL) doivent produire le
    même score, sinon la base et le pipeline signaleraient des paires différentes.
    """
    ca, cb = cle_comparaison(a), cle_comparaison(b)
    if not ca or not cb:
        return 0.0
    if ca == cb:
        return 1.0
    if len(ca) >= 4 and len(cb) >= 4 and (ca in cb or cb in ca):
        return 0.82  # contenance : indice, jamais une preuve de doublon

    def bigrammes(valeur: str) -> set[str]:
        return {valeur[i:i + 2] for i in range(max(len(valeur) - 1, 1))}

    paquets_a, paquets_b = bigrammes(ca), bigrammes(cb)
    total = len(paquets_a) + len(paquets_b)
    if total == 0:
        return 0.0
    return round(2.0 * len(paquets_a & paquets_b) / total, 4)


def non_vide(valeur: Any) -> bool:
    """Vrai si la valeur contient une information autre qu'un marqueur d'absence."""
    if valeur is None:
        return False
    if isinstance(valeur, str):
        texte = valeur.strip().lower()
        return texte not in {"", "none", "null", "inconnu", "inconnue", "n/a", "à confirmer", "a confirmer"}
    if isinstance(valeur, (list, tuple, set, dict)):
        return len(valeur) > 0
    return True
