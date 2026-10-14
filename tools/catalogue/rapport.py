"""Rapports d'import et de couverture du recensement national."""

from __future__ import annotations

from collections import Counter
from datetime import date
from typing import Any, Iterable

from .modele import Etablissement


def _pourcentage(partie: int, total: int) -> str:
    return f"{(100 * partie / total):.0f} %" if total else "—"


def rapport_couverture(
    etablissements: list[Etablissement], date_rapport: str | None = None
) -> dict[str, Any]:
    """Mesure la couverture réelle et les manques, sans extrapolation.

    La date est injectable pour que la vérification automatisée soit déterministe :
    régénérer le rapport un autre jour ne doit pas faire échouer la comparaison
    (la date retenue est celle du commit vérifié, pas celle du jour d'exécution).
    """
    total = len(etablissements)
    par_region = Counter(e.region or "Région non renseignée" for e in etablissements)
    par_commune = Counter(e.commune or e.ville_libre or "Commune non renseignée" for e in etablissements)
    par_type = Counter(e.type_etablissement or "non renseigné" for e in etablissements)
    par_niveau = Counter(e.niveau_verification for e in etablissements)

    avec_gps = sum(1 for e in etablissements if e.latitude is not None)
    gps_verifie = sum(1 for e in etablissements if e.gps_verifie)
    avec_telephone = sum(1 for e in etablissements if e.telephone)
    avec_whatsapp = sum(1 for e in etablissements if e.whatsapp)
    avec_adresse = sum(1 for e in etablissements if e.adresse_complete)
    avec_photos_authentiques = sum(
        1 for e in etablissements if any(not i.est_illustration_generique for i in e.images)
    )
    avec_illustration_generique = sum(
        1 for e in etablissements if any(i.est_illustration_generique for i in e.images)
    )
    avec_menus = sum(1 for e in etablissements if e.menus and any(p.prix is not None for m in e.menus for p in m.plats))
    plats_total = sum(len(m.plats) for e in etablissements for m in e.menus)
    avec_horaires = sum(1 for e in etablissements if e.horaires)
    avec_services = sum(1 for e in etablissements if e.services)
    avec_proprietaire = sum(
        1 for e in etablissements if any(x.statut_confirmation == "confirme" for x in e.exploitation)
    )
    avec_source = sum(1 for e in etablissements if e.sources)
    avec_date_collecte = sum(1 for e in etablissements if e.date_collecte)

    champs_manquants = Counter()
    for etablissement in etablissements:
        if not etablissement.adresse_complete:
            champs_manquants["adresse"] += 1
        if etablissement.latitude is None:
            champs_manquants["gps"] += 1
        if not etablissement.telephone:
            champs_manquants["telephone"] += 1
        if not etablissement.horaires:
            champs_manquants["horaires"] += 1
        if not etablissement.menus:
            champs_manquants["menu"] += 1
        if not any(not i.est_illustration_generique for i in etablissement.images):
            champs_manquants["photo_authentique"] += 1
        if not etablissement.sources:
            champs_manquants["source"] += 1

    rapport = {
        "date_rapport": date_rapport or date.today().isoformat(),
        "total_fiches": total,
        "regions_couvertes": sorted(par_region.keys()),
        "par_region": dict(par_region.most_common()),
        "par_commune": dict(par_commune.most_common(30)),
        "par_type_etablissement": dict(par_type.most_common()),
        "par_niveau_verification": dict(par_niveau.most_common()),
        "qualite": {
            "adresse_renseignee": avec_adresse,
            "gps_renseigne": avec_gps,
            "gps_verifie": gps_verifie,
            "telephone": avec_telephone,
            "whatsapp": avec_whatsapp,
            "horaires": avec_horaires,
            "services": avec_services,
            "menus_avec_prix": avec_menus,
            "plats_catalogue": plats_total,
            "photos_authentiques": avec_photos_authentiques,
            "illustrations_generiques_seulement": avec_illustration_generique,
            "proprietaire_confirme": avec_proprietaire,
            "avec_source": avec_source,
            "avec_date_collecte": avec_date_collecte,
        },
        "champs_manquants": dict(champs_manquants.most_common()),
        "limites": [
            "Le recensement s'appuie sur des sources publiques dont aucune ne garantit l'exhaustivité.",
            "Les annuaires consultés comportent des fiches déclaratives non contrôlées par DEKK FOOD.",
            "Les établissements sans présence en ligne ne peuvent être recensés que par relevé terrain.",
            "Aucune vérification téléphonique n'a été réalisée lors de cette phase : "
            "le niveau « partiellement vérifié » ne signifie pas « données confirmées par l'établissement ».",
        ],
    }
    return rapport


def rapport_couverture_markdown(rapport: dict[str, Any]) -> str:
    total = rapport["total_fiches"]
    qualite = rapport["qualite"]
    lignes: list[str] = [
        f"# Couverture du catalogue DEKK FOOD — {rapport['date_rapport']}",
        "",
        f"**{total} fiches** au total, réparties sur **{len(rapport['regions_couvertes'])} région(s)**.",
        "",
        "## Répartition par région",
        "",
        "| Région | Fiches |",
        "|---|---|",
    ]
    for region, nombre in rapport["par_region"].items():
        lignes.append(f"| {region} | {nombre} |")

    lignes += ["", "## Qualité des données", "", "| Indicateur | Fiches | Part |", "|---|---|---|"]
    for cle, valeur in qualite.items():
        part = _pourcentage(valeur, total) if isinstance(valeur, int) and cle != "plats_catalogue" else "—"
        lignes.append(f"| {cle.replace('_', ' ')} | {valeur} | {part} |")

    lignes += ["", "## Champs manquants", "", "| Champ | Fiches concernées |", "|---|---|"]
    for champ, nombre in rapport["champs_manquants"].items():
        lignes.append(f"| {champ} | {nombre} |")

    lignes += ["", "## Limites connues", ""]
    lignes += [f"- {limite}" for limite in rapport["limites"]]
    lignes.append("")
    return "\n".join(lignes)


def rapport_lot(
    nom_fichier: str,
    format_fichier: str,
    total_lignes: int,
    ajoutees: int,
    mises_a_jour: int,
    rejetees: list[dict[str, Any]],
    doublons: list[dict[str, Any]],
    a_verifier: list[dict[str, Any]],
) -> dict[str, Any]:
    """Rapport exigé après chaque lot d'import."""
    return {
        "fichier": nom_fichier,
        "format": format_fichier,
        "date": date.today().isoformat(),
        "total_lignes": total_lignes,
        "ajoutees": ajoutees,
        "mises_a_jour": mises_a_jour,
        "rejetees": len(rejetees),
        "doublons": len(doublons),
        "a_verifier": len(a_verifier),
        "detail_rejets": rejetees,
        "detail_doublons": doublons,
        "detail_a_verifier": a_verifier,
    }


def rapport_lot_markdown(rapport: dict[str, Any]) -> str:
    lignes = [
        f"# Rapport d'import — {rapport['fichier']}",
        "",
        f"- Format : {rapport['format']}",
        f"- Date : {rapport['date']}",
        f"- Lignes traitées : {rapport['total_lignes']}",
        f"- Ajoutées : {rapport['ajoutees']}",
        f"- Mises à jour : {rapport['mises_a_jour']}",
        f"- Rejetées : {rapport['rejetees']}",
        f"- Doublons détectés : {rapport['doublons']}",
        f"- À vérifier : {rapport['a_verifier']}",
        "",
    ]
    if rapport["detail_rejets"]:
        lignes += ["## Détail des rejets", ""]
        for rejet in rapport["detail_rejets"]:
            lignes.append(f"- {rejet.get('nom', '?')} : {rejet.get('raison', '')}")
        lignes.append("")
    if rapport["detail_doublons"]:
        lignes += ["## Doublons suspects (décision manuelle requise)", ""]
        for doublon in rapport["detail_doublons"]:
            lignes.append(f"- {doublon}")
        lignes.append("")
    return "\n".join(lignes)


def statistiques_par_region(etablissements: Iterable[Etablissement]) -> list[tuple[str, int]]:
    return Counter(e.region or "Non renseignée" for e in etablissements).most_common()
