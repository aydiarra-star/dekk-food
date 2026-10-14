#!/usr/bin/env python3
"""Plan d'enrichissement progressif du catalogue DEKK FOOD.

Construit, à partir des seules données collectées (aucune invention), une file de
travail hiérarchisée :

  P1 — vérification directe possible : l'établissement a un téléphone ou un
       WhatsApp professionnel. Un appel ou un message permet de confirmer
       horaires, menu, prix, services, photos autorisées et position.
  P2 — joignable indirectement : site web, page Facebook/Instagram ou e-mail
       seulement ; la prise de contact passe par un message écrit.
  P3 — aucun contact public : nécessite un passage sur place ou une source
       locale (le recensement ne peut pas progresser autrement).

Les régions les moins couvertes sont prioritaires à priorité égale : c'est le
seul levier mesurable pour équilibrer la couverture nationale.

Sorties :
  - docs/PLAN_ENRICHISSEMENT.md        (plan lisible, chiffré, révisable)
  - data/exports/file_de_travail_verification.csv (file de travail terrain)

Exécution :
    python3 tools/catalogue/plan_enrichissement.py
    python3 tools/catalogue/plan_enrichissement.py --md docs/PLAN_ENRICHISSEMENT.md
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

if __package__ in (None, ""):  # exécution directe : python tools/catalogue/plan_enrichissement.py
    sys.path.append(str(Path(__file__).resolve().parents[2]))

from tools.catalogue import normalisation as norm
from tools.catalogue.modele import Etablissement

RACINE = Path(__file__).resolve().parents[2]
DOSSIER_SEEDS = RACINE / "data" / "seed"
CHEMIN_MD = RACINE / "docs" / "PLAN_ENRICHISSEMENT.md"
CHEMIN_CSV = RACINE / "data" / "exports" / "file_de_travail_verification.csv"

# Champs à collecter, dans l'ordre où un appel les obtient naturellement.
CHAMPS_A_VERIFIER = [
    ("horaires", "Horaires réels par jour, jours de fermeture, service midi/soir"),
    ("telephone", "Numéro professionnel actif (et confirmation de celui déjà collecté)"),
    ("menu", "Plats et boissons réellement servis, avec prix en FCFA"),
    ("photos", "Photos de l'établissement fournies par le restaurateur, avec autorisation écrite"),
    ("gps", "Position exacte (relevé sur place ou partage de localisation)"),
    ("services", "Sur place, à emporter, livraison, réservation, traiteur"),
    ("paiement", "Moyens de paiement acceptés (Wave, Orange Money, carte, espèces)"),
    ("exploitation", "Propriétaire/gérant — uniquement s'il est documenté ou s'il autorise la publication"),
]


def charger_fiches(dossier: Path = DOSSIER_SEEDS) -> list[Etablissement]:
    fiches: list[Etablissement] = []
    for fichier in sorted(dossier.glob("*.json")):
        donnees = json.loads(fichier.read_text(encoding="utf-8"))
        for brut in donnees.get("etablissements", []):
            fiches.append(Etablissement.depuis_dict(brut))
    return fiches


def _contact_direct(etablissement: Etablissement) -> list[str]:
    contacts = []
    for type_contact in ("telephone", "whatsapp"):
        contact = etablissement.contact(type_contact)
        if contact and norm.non_vide(contact.valeur):
            contacts.append(type_contact)
    return contacts


def _contact_indirect(etablissement: Etablissement) -> list[str]:
    contacts = []
    email = etablissement.contact("email")
    if email and norm.non_vide(email.valeur):
        contacts.append("email")
    if norm.non_vide(etablissement.site_web):
        contacts.append("site_web")
    if norm.non_vide(etablissement.facebook):
        contacts.append("facebook")
    if norm.non_vide(etablissement.instagram):
        contacts.append("instagram")
    return contacts


def _champs_manquants(etablissement: Etablissement) -> list[str]:
    manquants = []
    if not etablissement.horaires:
        manquants.append("horaires")
    if not etablissement.telephone:
        manquants.append("telephone")
    if not any(plat.prix is not None for menu in etablissement.menus for plat in menu.plats):
        manquants.append("menu_et_prix")
    if not any(not image.est_illustration_generique for image in etablissement.images):
        manquants.append("photo_authentique")
    if etablissement.latitude is None or not etablissement.gps_verifie:
        manquants.append("gps_verifie")
    if not etablissement.services:
        manquants.append("services")
    if not etablissement.modes_paiement:
        manquants.append("moyens_de_paiement")
    if etablissement.derniere_verification_le is None:
        manquants.append("verification_humaine")
    return manquants


def construire_plan(fiches: Iterable[Etablissement]) -> dict[str, Any]:
    fiches = list(fiches)
    compteur_regions = Counter(f.region or "Région non renseignée" for f in fiches)
    entrees: list[dict[str, Any]] = []

    for etablissement in fiches:
        directs = _contact_direct(etablissement)
        indirects = _contact_indirect(etablissement)
        if directs:
            priorite, niveau = 1, "verification_directe"
        elif indirects:
            priorite, niveau = 2, "contact_indirect"
        else:
            priorite, niveau = 3, "releve_terrain"

        region = etablissement.region or "Région non renseignée"
        entrees.append(
            {
                "numero_fiche": etablissement.numero_fiche or etablissement.cle,
                "nom": etablissement.nom,
                "region": region,
                "commune": etablissement.commune or etablissement.ville_libre or "",
                "type_etablissement": etablissement.type_etablissement or "",
                "priorite": priorite,
                "niveau_contact": niveau,
                "contacts_directs": " + ".join(directs),
                "contacts_indirects": " + ".join(indirects),
                "telephone": etablissement.telephone or "",
                "whatsapp": etablissement.whatsapp or "",
                "latitude": etablissement.latitude,
                "longitude": etablissement.longitude,
                "champs_manquants": ", ".join(_champs_manquants(etablissement)),
                "fiches_region": compteur_regions[region],
                "niveau_verification": etablissement.niveau_verification,
                "publiee": etablissement.publication.visible,
                "action_attendue": (
                    "Appel ou message WhatsApp au numéro publié : confirmer horaires, menu et prix, "
                    "services, moyens de paiement, position, demander l'accord d'image."
                    if priorite == 1
                    else (
                        "Message écrit via le site ou la page professionnelle : présenter DEKK FOOD, "
                        "demander les informations manquantes et l'accord d'image."
                        if priorite == 2
                        else (
                            "Aucun contact public : passage sur place ou appui d'une source locale "
                            "(mairie, office de tourisme, association de restaurateurs)."
                        )
                    )
                ),
            }
        )

    # Tri : priorité, puis région la moins couverte, puis commune, puis nom.
    entrees.sort(
        key=lambda e: (
            e["priorite"],
            e["fiches_region"],
            e["region"],
            e["commune"],
            e["nom"].lower(),
        )
    )
    for rang, entree in enumerate(entrees, start=1):
        entree["rang"] = rang

    return {
        "total": len(fiches),
        "par_priorite": dict(Counter(e["priorite"] for e in entrees)),
        "par_region": dict(compteur_regions.most_common()),
        "par_region_priorite_1": dict(
            Counter(e["region"] for e in entrees if e["priorite"] == 1).most_common()
        ),
        "entrees": entrees,
    }


def ecrire_csv(plan: dict[str, Any], chemin: Path) -> None:
    chemin.parent.mkdir(parents=True, exist_ok=True)
    colonnes = [
        "rang", "priorite", "niveau_contact", "numero_fiche", "nom", "region", "commune",
        "type_etablissement", "fiches_region", "telephone", "whatsapp", "contacts_directs",
        "contacts_indirects", "latitude", "longitude", "champs_manquants",
        "niveau_verification", "publiee", "action_attendue",
    ]
    with chemin.open("w", encoding="utf-8", newline="") as flux:
        redacteur = csv.DictWriter(flux, fieldnames=colonnes, delimiter=";")
        redacteur.writeheader()
        for entree in plan["entrees"]:
            redacteur.writerow({colonne: entree.get(colonne, "") for colonne in colonnes})


def ecrire_markdown(plan: dict[str, Any], chemin: Path, date_plan: str) -> None:
    p1, p2, p3 = (plan["par_priorite"].get(rang, 0) for rang in (1, 2, 3))
    lignes = [
        f"# Plan d'enrichissement du catalogue DEKK FOOD — {date_plan}",
        "",
        f"**{plan['total']} fiches** au total. Ce plan est calculé à partir des données réellement "
        "collectées (aucune estimation) : il indique par quoi commencer pour que le recensement "
        "progresse de façon vérifiable.",
        "",
        "## Priorités",
        "",
        "| Priorité | Fiches | Principe |",
        "|---|---|---|",
        f"| **P1 — vérification directe** | {p1} | L'établissement a un téléphone ou un WhatsApp "
        "professionnel : un appel ou un message confirme horaires, menu, prix, services, moyens de "
        "paiement, position et recueille l'autorisation d'image. |",
        f"| **P2 — contact indirect** | {p2} | Seuls un site web, une page professionnelle ou un e-mail "
        "sont connus : prise de contact écrite. |",
        f"| **P3 — relevé terrain** | {p3} | Aucun contact public : sans passage sur place ou appui "
        "d'une source locale, la fiche ne peut pas progresser. |",
        "",
        "À priorité égale, les **régions les moins couvertes** passent d'abord : c'est le seul levier "
        "mesurable pour équilibrer la couverture nationale.",
        "",
        "## Ce qu'un appel doit obtenir",
        "",
        "| Champ | Ce qui est demandé |",
        "|---|---|",
    ]
    lignes += [f"| `{champ}` | {description} |" for champ, description in CHAMPS_A_VERIFIER]
    lignes += [
        "",
        "L'appel est enregistré comme **source** de la fiche (date, interlocuteur, fonction, "
        "informations confirmées). Une information obtenue au téléphone passe la fiche en "
        "« partiellement vérifié » ; le badge « vérifié » exige une validation tracée dans la base "
        "(`public.valider_fiche_par_controle`), avec la preuve correspondante.",
        "",
        "## Charge par région",
        "",
        "| Région | Fiches | Dont vérification directe possible (P1) |",
        "|---|---|---|",
    ]
    for region, total in plan["par_region"].items():
        p1_region = plan["par_region_priorite_1"].get(region, 0)
        lignes.append(f"| {region} | {total} | {p1_region} |")
    lignes += [
        "",
        "## Les 30 premiers appels (extrait de la file de travail)",
        "",
        "| # | Fiche | Nom | Région | Commune | Téléphone | WhatsApp | Champs manquants |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for entree in plan["entrees"][:30]:
        lignes.append(
            f"| {entree['rang']} | {entree['numero_fiche']} | {entree['nom']} | {entree['region']} | "
            f"{entree['commune'] or '—'} | {entree['telephone'] or '—'} | {entree['whatsapp'] or '—'} | "
            f"{entree['champs_manquants']} |"
        )
    lignes += [
        "",
        f"File complète, triée et exportable : `{CHEMIN_CSV.relative_to(RACINE).as_posix()}` "
        f"({plan['total']} lignes). Les fiches non publiées y figurent aussi : elles ont besoin "
        "d'une vérification avant toute publication.",
        "",
        "## Règles qui s'appliquent pendant l'enrichissement",
        "",
        "- Aucune donnée n'est inventée : un champ non obtenu reste vide et affiché comme manquant.",
        "- Un prix, un horaire ou un service n'est marqué confirmé qu'avec la source correspondante.",
        "- Une photo n'est publiée qu'avec l'autorisation écrite du restaurateur (référence et date "
        "enregistrées) ; à défaut elle reste une illustration générique étiquetée comme telle.",
        "- Le propriétaire n'est publié que s'il est documenté ou s'il autorise explicitement la "
        "publication ; sinon « Propriétaire non renseigné ».",
        "- Aucune fusion de fiches automatique : un rapprochement est proposé puis arbitré par un humain.",
        "",
    ]
    chemin.parent.mkdir(parents=True, exist_ok=True)
    chemin.write_text("\n".join(lignes), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    analyseur = argparse.ArgumentParser(description="Plan d'enrichissement du catalogue DEKK FOOD")
    analyseur.add_argument("--md", default=str(CHEMIN_MD), help="chemin du plan Markdown")
    analyseur.add_argument("--csv", default=str(CHEMIN_CSV), help="chemin de la file de travail CSV")
    analyseur.add_argument("--date", default=None, help="date du plan (AAAA-MM-JJ)")
    arguments = analyseur.parse_args(argv)

    from datetime import date as _date

    fiches = charger_fiches()
    if not fiches:
        print("Aucune fiche : rien à planifier.", file=sys.stderr)
        return 1
    plan = construire_plan(fiches)
    jour = arguments.date or _date.today().isoformat()
    ecrire_csv(plan, Path(arguments.csv))
    ecrire_markdown(plan, Path(arguments.md), jour)

    print(f"Plan écrit dans {arguments.md}")
    print(f"File de travail écrite dans {arguments.csv}")
    print(f"  total            : {plan['total']}")
    print(f"  P1 direct        : {plan['par_priorite'].get(1, 0)}")
    print(f"  P2 indirect      : {plan['par_priorite'].get(2, 0)}")
    print(f"  P3 terrain       : {plan['par_priorite'].get(3, 0)}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
