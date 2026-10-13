"""Détection des doublons — suggestion uniquement, jamais de fusion automatique.

Règles métier (cahier des charges §7 et §8) :
- deux noms similaires ne suffisent JAMAIS à conclure à un doublon ;
- les indices forts sont le site web, le téléphone, le WhatsApp et la proximité GPS ;
- toute fusion reste une décision humaine, tracée dans `doublons_suspects`.
"""

from __future__ import annotations

from dataclasses import dataclass

from .modele import Etablissement
from . import normalisation as norm

POIDS = {
    "site_web_identique": 0.30,
    "whatsapp_identique": 0.25,
    "telephone_identique": 0.20,
    "gps_proche": 0.15,
    "adresse_identique": 0.10,
    "quartier_identique": 0.05,
}


@dataclass
class Candidat:
    """Paire d'établissements suspects de doublon."""

    a: Etablissement
    b: Etablissement
    score: float
    motifs: list[str]

    def resume(self) -> str:
        motifs = ", ".join(self.motifs) if self.motifs else "similarité de nom uniquement"
        return f"{self.a.nom} ⇄ {self.b.nom} — score {self.score:.2f} ({motifs})"


def similarite_noms(a: str, b: str) -> float:
    """Similarité de deux noms, calculée sur les mots significatifs.

    Les mots génériques (« restaurant », « chez », « hôtel »…) sont ignorés :
    sinon « Restaurant Le Lagon 1 » et « Restaurant La Douma » seraient déclarés
    proches alors qu'ils n'ont rien en commun. Deux noms identiques restent à 1.0.

    La formule est identique à celle de la fonction SQL `public.similarite_noms`
    (Dice des mots, Jaccard des mots, ressemblance des identifiants, contenance
    plafonnée à 0,82) pour que la base et le pipeline détectent les mêmes paires.
    """
    ca, cb = norm.cle_comparaison(a), norm.cle_comparaison(b)
    if not ca or not cb:
        return 0.0
    if ca == cb:
        return 1.0

    mots_a, mots_b = norm.mots_significatifs(a), norm.mots_significatifs(b)
    if not mots_a or not mots_b:
        return norm.similarite_bigrammes(ca, cb)

    identifiant_a, identifiant_b = " ".join(sorted(mots_a)), " ".join(sorted(mots_b))
    communs = len(mots_a & mots_b)
    total = len(mots_a) + len(mots_b)
    score = max(
        2.0 * communs / total if total else 0.0,
        communs / len(mots_a | mots_b) if mots_a | mots_b else 0.0,
        norm.similarite_bigrammes(identifiant_a, identifiant_b),
    )
    # Contenance (ex. « baobab » ⊆ « baobab saly ») : indice, pas preuve.
    # Le garde-fou sur la longueur évite les faux positifs sur les identifiants
    # très courts (« b » de « Maison B » serait « contenu » dans presque tout).
    if len(identifiant_a) >= 4 and len(identifiant_b) >= 4:
        if identifiant_a in identifiant_b or identifiant_b in identifiant_a:
            score = max(score, 0.82)
    return round(score, 4)


def distance_gps(a: Etablissement, b: Etablissement) -> float | None:
    if None in (a.latitude, a.longitude, b.latitude, b.longitude):
        return None
    from math import asin, cos, radians, sin, sqrt

    lat1, lon1, lat2, lon2 = a.latitude, a.longitude, b.latitude, b.longitude
    dlat, dlon = radians(lat2 - lat1), radians(lon2 - lon1)
    h = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
    return 6371000 * 2 * asin(sqrt(h))


_MARQUEURS_VOIE = (
    "rue", "avenue", "av.", "boulevard", "bd", "route", "rte", "rond-point", "plac",
    "impasse", "allee", "allée", "cite", "cité", "villa", "km",
)


def _adresse_precise(adresse: str) -> bool:
    """Vrai si l'adresse désigne une voie identifiable et non « Ville, quartier »."""
    texte = norm.sans_accents(adresse or "").lower()
    if any(marqueur in texte for marqueur in _MARQUEURS_VOIE):
        return True
    return any(caractere.isdigit() for caractere in texte)


def comparer(a: Etablissement, b: Etablissement, distance_max_m: int = 150) -> Candidat:
    """Compare deux fiches et renvoie un candidat avec ses motifs."""
    motifs: list[str] = []

    if a.site_web and b.site_web and a.site_web == b.site_web:
        motifs.append("site_web_identique")
    if a.whatsapp and b.whatsapp and a.whatsapp == b.whatsapp:
        motifs.append("whatsapp_identique")
    if a.telephone and b.telephone and a.telephone == b.telephone:
        motifs.append("telephone_identique")

    distance = distance_gps(a, b)
    if distance is not None and distance <= distance_max_m:
        motifs.append("gps_proche")
    if a.adresse_complete and b.adresse_complete:
        # Une adresse générique (« Ngor, Dakar ») ne prouve rien : on ne retient
        # l'égalité d'adresse que si les deux libellés désignent une voie précise.
        if _adresse_precise(a.adresse_complete) and _adresse_precise(b.adresse_complete) \
                and norm.cle_comparaison(a.adresse_complete) == norm.cle_comparaison(b.adresse_complete):
            motifs.append("adresse_identique")
    quartier_a = a.quartier or a.quartier_libre
    quartier_b = b.quartier or b.quartier_libre
    if quartier_a and quartier_b and norm.cle_comparaison(quartier_a) == norm.cle_comparaison(quartier_b):
        motifs.append("quartier_identique")

    score_nom = similarite_noms(a.nom, b.nom)
    score = score_nom + sum(POIDS[m] for m in motifs)

    # Une localisation divergente affaiblit l'hypothèse de doublon : deux villes
    # différentes pour un même nom sont le plus souvent deux établissements distincts.
    if a.region and b.region and norm.cle_comparaison(a.region) != norm.cle_comparaison(b.region):
        score -= 0.20
    elif a.commune and b.commune and norm.cle_comparaison(a.commune) != norm.cle_comparaison(b.commune):
        score -= 0.15

    # Un même site web / WhatsApp / téléphone pour deux fiches est un signal fort
    # à lui seul : on remonte le score pour que la paire soit examinée, même si
    # les noms ne se ressemblent pas (ex. deux enseignes d'un même exploitant).
    if any(motif in motifs for motif in ("site_web_identique", "whatsapp_identique", "telephone_identique")):
        score = max(score, 0.50)

    return Candidat(a=a, b=b, score=min(1.0, round(score, 4)), motifs=motifs)


def detecter(
    etablissements: list[Etablissement],
    seuil: float = 0.62,
    seuil_contact: float = 0.50,
) -> list[Candidat]:
    """Renvoie les paires suspectes triées par score décroissant.

    Deux seuils :
    - `seuil` (0.62) pour les ressemblances de nom, volontairement bas : on préfère
      proposer une paire à examiner plutôt que de manquer un vrai doublon ;
    - `seuil_contact` (0.50) dès qu'un site web, un téléphone ou un WhatsApp est
      partagé entre deux fiches, car ce signal ne dépend pas du nom.

    La fusion reste TOUJOURS une décision humaine.
    """
    candidats: list[Candidat] = []
    motifs_forts = {"site_web_identique", "whatsapp_identique", "telephone_identique"}
    for i, a in enumerate(etablissements):
        for b in etablissements[i + 1:]:
            candidat = comparer(a, b)
            limite = seuil_contact if motifs_forts & set(candidat.motifs) else seuil
            if candidat.score >= limite:
                candidats.append(candidat)
    candidats.sort(key=lambda c: c.score, reverse=True)
    return candidats
