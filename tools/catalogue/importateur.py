#!/usr/bin/env python3
"""Importation et gestion du catalogue DEKK FOOD.

Exemples :
    python -m tools.catalogue.importateur valider data/seed/etablissements_2026-10-13.json
    python -m tools.catalogue.importateur dedoublonner data/seed/*.json
    python -m tools.catalogue.importateur generer --dossier .
    python -m tools.catalogue.importateur rapport data/seed/*.json --sortie docs/RAPPORT_COUVERTURE.md
    python -m tools.catalogue.importateur importer data/seed/etablissements.csv --base "$DATABASE_URL"
    python -m tools.catalogue.importateur exporter --format csv --sortie export_catalogue.csv
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

if __package__ in (None, ""):  # exécution directe : python tools/catalogue/importateur.py
    sys.path.append(str(Path(__file__).resolve().parents[2]))

from tools.catalogue import dedoublonnage, generation, rapport as module_rapport
from tools.catalogue.modele import Etablissement, charger_etablissements

RACINE = Path(__file__).resolve().parents[2]
CHEMIN_ASSET = RACINE / "assets" / "data" / "catalogue.json"
CHEMIN_SEED_SQL = RACINE / "supabase" / "seed" / "10_etablissements.sql"


@dataclass
class Resultat:
    """Résultat d'un import, utilisé pour les rapports et l'API d'administration."""

    etablissements: list[Etablissement] = field(default_factory=list)
    rejets: list[dict[str, Any]] = field(default_factory=list)
    doublons: list[dict[str, Any]] = field(default_factory=list)
    a_verifier: list[dict[str, Any]] = field(default_factory=list)
    total_lignes: int = 0


# --------------------------------------------------------------------------- #
# Lecture des fichiers sources (CSV, XLSX, JSON)
# --------------------------------------------------------------------------- #
def lire_json(chemin: Path) -> dict[str, Any]:
    return json.loads(chemin.read_text(encoding="utf-8"))


def lire_csv(chemin: Path, separateur: str = ";") -> list[dict[str, Any]]:
    """Lit un CSV à plat (modèle d'import colonne par colonne)."""
    with chemin.open(encoding="utf-8-sig", newline="") as fichier:
        lecteur = csv.DictReader(fichier, delimiter=separateur)
        return [dict(ligne) for ligne in lecteur]


def lire_xlsx(chemin: Path, feuille: str | None = None) -> list[dict[str, Any]]:
    """Lit un classeur Excel (dépendance optionnelle `openpyxl`)."""
    try:
        from openpyxl import load_workbook  # type: ignore
    except ImportError as exc:  # pragma: no cover - dépendance optionnelle
        raise RuntimeError(
            "Lecture XLSX indisponible : installez openpyxl (`pip install -r tools/requirements.txt`)."
        ) from exc

    classeur = load_workbook(chemin, read_only=True, data_only=True)
    feuille_active = classeur[feuille] if feuille else classeur.worksheets[0]
    lignes = list(feuille_active.iter_rows(values_only=True))
    if not lignes:
        return []
    entetes = [str(cellule).strip() if cellule is not None else "" for cellule in lignes[0]]
    resultat: list[dict[str, Any]] = []
    for ligne in lignes[1:]:
        if ligne is None or all(cellule is None for cellule in ligne):
            continue
        resultat.append({entete: valeur for entete, valeur in zip(entetes, ligne) if entete})
    return resultat


def convertir_ligne_plate(ligne: dict[str, Any], source: str | None = None) -> dict[str, Any]:
    """Convertit une ligne CSV/XLSX à plat en fiche structurée.

    Le modèle d'import (data/templates/modele_import.csv) utilise une colonne par
    information ; les listes se séparent par « | ».
    """
    def valeur(cle: str) -> Any:
        brut = ligne.get(cle)
        if brut is None:
            return None
        texte = str(brut).strip()
        return texte or None

    def liste(cle: str) -> list[str]:
        brut = valeur(cle)
        return [element.strip() for element in brut.split("|") if element.strip()] if brut else []

    fiche: dict[str, Any] = {
        "cle": valeur("cle") or valeur("slug") or valeur("nom"),
        "nom": valeur("nom"),
        "nom_officiel": valeur("nom_officiel"),
        "nom_commercial": valeur("nom_commercial"),
        "type_etablissement": valeur("type_etablissement"),
        "categories": liste("categories"),
        "cuisine_type": valeur("cuisine_type"),
        "description_courte": valeur("description_courte"),
        "statut": valeur("statut") or "a_verifier",
        "niveau_verification": valeur("niveau_verification") or "a_confirmer",
        "adresse": {
            "region": valeur("region"),
            "departement": valeur("departement"),
            "commune": valeur("commune"),
            "quartier": valeur("quartier"),
            "quartier_libre": valeur("quartier_libre"),
            "ville_libre": valeur("ville_libre"),
            "adresse_complete": valeur("adresse") or valeur("adresse_complete"),
            "latitude": valeur("latitude"),
            "longitude": valeur("longitude"),
            "gps_verifie": str(valeur("gps_verifie") or "").lower() in {"1", "true", "oui", "vrai"},
        },
        "contacts": [],
        "services": liste("services"),
        "modes_paiement": liste("modes_paiement"),
        "date_collecte": valeur("date_collecte"),
        "derniere_verification_le": valeur("derniere_verification_le"),
        "origine_donnee": valeur("origine_donnee") or source,
        "est_publication_visible": str(valeur("est_publication_visible") or "non").lower()
        in {"1", "true", "oui", "vrai"},
        "sources": [{"source": source, "url": valeur("source_url"), "date_collecte": valeur("date_collecte"),
                     "donnees": valeur("source_donnees") or "import fichier"}]
        if source
        else ([{"source": "application_existante", "date_collecte": valeur("date_collecte")}]
              if valeur("source_url") is None else []),
    }

    for colonne, type_contact in (
        ("telephone", "telephone"),
        ("whatsapp", "whatsapp"),
        ("email", "email"),
        ("site_web", "site_web"),
        ("facebook", "facebook"),
        ("instagram", "instagram"),
        ("commande_en_ligne_url", "commande_en_ligne"),
        ("reservation_url", "reservation"),
    ):
        brut = valeur(colonne)
        if brut:
            fiche["contacts"].append(
                {
                    "type": type_contact,
                    "valeur": brut,
                    "confirme": False,
                    "source": source,
                    "date_collecte": valeur("date_collecte"),
                }
            )

    prix_min, prix_max = valeur("fourchette_prix_min"), valeur("fourchette_prix_max")
    if prix_min or prix_max:
        fiche["fourchette_prix"] = {"min": prix_min, "max": prix_max, "devise": valeur("devise") or "XOF"}

    return fiche


# --------------------------------------------------------------------------- #
# Chargement et validation
# --------------------------------------------------------------------------- #
def charger_fichiers(chemins: Iterable[str], source: str | None = None) -> Resultat:
    """Charge un ou plusieurs fichiers CSV / XLSX / JSON."""
    resultat = Resultat()
    for chemin_texte in chemins:
        chemin = Path(chemin_texte)
        if not chemin.exists():
            resultat.rejets.append({"nom": chemin_texte, "raison": "fichier introuvable"})
            continue

        extension = chemin.suffix.lower()
        try:
            if extension == ".json":
                donnees = lire_json(chemin)
                if isinstance(donnees, list):
                    donnees = {"etablissements": donnees}
                brut = donnees.get("etablissements", [])
            elif extension == ".csv":
                brut = [convertir_ligne_plate(ligne, source) for ligne in lire_csv(chemin)]
            elif extension in {".xlsx", ".xlsm"}:
                brut = [convertir_ligne_plate(ligne, source) for ligne in lire_xlsx(chemin)]
            else:
                resultat.rejets.append({"nom": chemin.name, "raison": f"format non pris en charge : {extension}"})
                continue
        except Exception as exc:  # noqa: BLE001 - le message est restitué tel quel dans le rapport
            resultat.rejets.append({"nom": chemin.name, "raison": f"lecture impossible : {exc}"})
            continue

        source_fichier = source or chemin.stem
        for index, item in enumerate(brut, start=1):
            resultat.total_lignes += 1
            if source_fichier and not item.get("sources"):
                item["sources"] = [{"source": source_fichier, "date_collecte": item.get("date_collecte")}]
            etablissement = Etablissement.depuis_dict(item)
            problemes = etablissement.valider()
            erreurs = [p for p in problemes if p.niveau == "erreur"]
            avertissements = [p for p in problemes if p.niveau == "avertissement"]
            if erreurs:
                resultat.rejets.append(
                    {
                        "nom": etablissement.nom or f"{chemin.name}:{index}",
                        "ligne": index,
                        "raison": " ; ".join(p.message for p in erreurs),
                    }
                )
                continue
            if avertissements:
                resultat.a_verifier.append(
                    {
                        "nom": etablissement.nom,
                        "ligne": index,
                        "avertissements": [p.message for p in avertissements],
                    }
                )
            resultat.etablissements.append(etablissement)
    return resultat


# --------------------------------------------------------------------------- #
# Application en base
# --------------------------------------------------------------------------- #
def appliquer_en_base(url: str, sql: str) -> None:
    """Exécute le SQL généré sur la base cible."""
    try:
        import psycopg  # type: ignore
    except ImportError as exc:  # pragma: no cover
        raise RuntimeError("psycopg est requis pour l'import en base (`pip install -r tools/requirements.txt`).") from exc

    with psycopg.connect(url) as connexion:
        with connexion.cursor() as curseur:
            curseur.execute(sql)
        connexion.commit()


def enregistrer_lot(url: str, nom_fichier: str, format_fichier: str, resultat: Resultat) -> None:
    """Trace le lot d'import dans import_lots / import_lignes."""
    try:
        import psycopg  # type: ignore
    except ImportError as exc:  # pragma: no cover
        raise RuntimeError("psycopg est requis pour tracer un lot d'import.") from exc

    rapport_lot = module_rapport.rapport_lot(
        nom_fichier=nom_fichier,
        format_fichier=format_fichier,
        total_lignes=resultat.total_lignes,
        ajoutees=len(resultat.etablissements),
        mises_a_jour=0,
        rejetees=resultat.rejets,
        doublons=resultat.doublons,
        a_verifier=resultat.a_verifier,
    )
    with psycopg.connect(url) as connexion, connexion.cursor() as curseur:
        curseur.execute(
            """
            insert into public.import_lots (nom_fichier, format, entre_par, statut, total_lignes, ajoutees,
                                            rejetees, doublons, a_verifier, rapport, termine_le)
            values (%s, %s, %s, 'termine', %s, %s, %s, %s, %s, %s, now())
            returning id
            """,
            (
                nom_fichier,
                format_fichier,
                "tools/catalogue",
                resultat.total_lignes,
                len(resultat.etablissements),
                len(resultat.rejets),
                len(resultat.doublons),
                len(resultat.a_verifier),
                json.dumps(rapport_lot, ensure_ascii=False),
            ),
        )
        lot_id = curseur.fetchone()[0]
        for position, etablissement in enumerate(resultat.etablissements, start=1):
            curseur.execute(
                """
                insert into public.import_lignes (lot_id, numero_ligne, donnees, statut, restaurant_id)
                values (%s, %s, %s, 'ajoutee',
                        (select id from public.restaurants where slug = %s))
                """,
                (lot_id, position, json.dumps(etablissement.as_dict(), ensure_ascii=False), etablissement.slug),
            )
        connexion.commit()


# --------------------------------------------------------------------------- #
# Export
# --------------------------------------------------------------------------- #
def exporter_csv(etablissements: list[Etablissement], chemin: Path) -> None:
    colonnes = [
        "numero_fiche", "nom", "nom_commercial", "type_etablissement", "categories", "cuisine_type",
        "statut", "niveau_verification", "region", "departement", "commune", "quartier", "quartier_libre",
        "adresse_complete", "latitude", "longitude", "gps_verifie", "telephone", "whatsapp", "site_web",
        "fourchette_prix_min", "fourchette_prix_max", "devise", "services", "plats", "date_collecte",
        "derniere_verification_le", "sources",
    ]
    chemin.parent.mkdir(parents=True, exist_ok=True)
    with chemin.open("w", encoding="utf-8", newline="") as fichier:
        ecrivain = csv.DictWriter(fichier, fieldnames=colonnes, delimiter=";")
        ecrivain.writeheader()
        for etablissement in etablissements:
            ecrivain.writerow(
                {
                    "numero_fiche": etablissement.numero_fiche,
                    "nom": etablissement.nom,
                    "nom_commercial": etablissement.nom_commercial,
                    "type_etablissement": etablissement.type_etablissement,
                    "categories": "|".join(etablissement.categories),
                    "cuisine_type": etablissement.cuisine_type,
                    "statut": etablissement.statut,
                    "niveau_verification": etablissement.niveau_verification,
                    "region": etablissement.region,
                    "departement": etablissement.departement,
                    "commune": etablissement.commune,
                    "quartier": etablissement.quartier,
                    "quartier_libre": etablissement.quartier_libre,
                    "adresse_complete": etablissement.adresse_complete,
                    "latitude": etablissement.latitude,
                    "longitude": etablissement.longitude,
                    "gps_verifie": etablissement.gps_verifie,
                    "telephone": etablissement.telephone,
                    "whatsapp": etablissement.whatsapp,
                    "site_web": etablissement.site_web,
                    "fourchette_prix_min": etablissement.fourchette_prix_min,
                    "fourchette_prix_max": etablissement.fourchette_prix_max,
                    "devise": etablissement.devise,
                    "services": "|".join(etablissement.services),
                    "plats": sum(len(m.plats) for m in etablissement.menus),
                    "date_collecte": etablissement.date_collecte,
                    "derniere_verification_le": etablissement.derniere_verification_le,
                    "sources": "|".join(s.code for s in etablissement.sources),
                }
            )


# --------------------------------------------------------------------------- #
# Ligne de commande
# --------------------------------------------------------------------------- #
def commande_valider(arguments: argparse.Namespace) -> int:
    resultat = charger_fichiers(arguments.fichiers, arguments.source)
    print(f"Lignes lues           : {resultat.total_lignes}")
    print(f"Fiches valides        : {len(resultat.etablissements)}")
    print(f"Fiches rejetées       : {len(resultat.rejets)}")
    print(f"Fiches à vérifier     : {len(resultat.a_verifier)}")
    for rejet in resultat.rejets:
        print(f"  ✗ {rejet['nom']} : {rejet['raison']}")
    for avertissement in resultat.a_verifier:
        print(f"  ! {avertissement['nom']} : {' ; '.join(avertissement['avertissements'][:3])}")
    doublons_slug = dedoublonnage.slugs_dupliques(resultat.etablissements)
    if doublons_slug:
        print(f"Slugs dupliqués        : {len(doublons_slug)} (une seule fiche par slug est conservée en base)")
        for slug, noms in doublons_slug.items():
            print(f"  ✗ {slug} : " + " | ".join(noms))
    return 1 if resultat.rejets or doublons_slug else 0


def commande_dedoublonner(arguments: argparse.Namespace) -> int:
    resultat = charger_fichiers(arguments.fichiers, arguments.source)
    candidats = dedoublonnage.detecter(resultat.etablissements, seuil=arguments.seuil)
    print(f"{len(candidats)} paire(s) suspecte(s) sur {len(resultat.etablissements)} fiches.")
    for candidat in candidats:
        print(f"  • {candidat.resume()}")
    print(
        "\nAucune fusion automatique n'est effectuée : chaque paire doit être confirmée "
        "ou écartée par un humain (signalements enregistrés dans doublons_suspects)."
    )
    return 0


def commande_generer(arguments: argparse.Namespace) -> int:
    resultat = charger_fichiers(arguments.fichiers, arguments.source)
    doublons_slug = dedoublonnage.slugs_dupliques(resultat.etablissements)
    if doublons_slug:
        print("Génération refusée : plusieurs fiches partagent le même slug, la base en écraserait.")
        for slug, noms in doublons_slug.items():
            print(f"  ✗ {slug} : " + " | ".join(noms))
        print("Corrigez les numéros de fiche ou les slugs avant de relancer la génération.")
        return 1
    dossier = Path(arguments.dossier).resolve()
    chemin_asset = dossier / "assets" / "data" / "catalogue.json"
    chemin_sql = dossier / "supabase" / "seed" / "10_etablissements.sql"

    catalogue = generation.construire_catalogue(resultat.etablissements)
    generation.ecrire_fichier(chemin_asset, json.dumps(catalogue, ensure_ascii=False, indent=1))
    generation.ecrire_fichier(chemin_sql, generation.generer_sql(resultat.etablissements))

    print(f"{len(resultat.etablissements)} fiches écrites dans {chemin_asset}")
    print(f"Script SQL d'amorçage écrit dans {chemin_sql}")
    if arguments.rapport:
        rapport_couverture = module_rapport.rapport_couverture(resultat.etablissements)
        generation.ecrire_fichier(
            Path(arguments.rapport), module_rapport.rapport_couverture_markdown(rapport_couverture)
        )
        print(f"Rapport de couverture écrit dans {arguments.rapport}")
    return 0


def commande_rapport(arguments: argparse.Namespace) -> int:
    resultat = charger_fichiers(arguments.fichiers, arguments.source)
    rapport_couverture = module_rapport.rapport_couverture(resultat.etablissements)
    texte = (
        json.dumps(rapport_couverture, ensure_ascii=False, indent=2)
        if arguments.format == "json"
        else module_rapport.rapport_couverture_markdown(rapport_couverture)
    )
    if arguments.sortie:
        generation.ecrire_fichier(Path(arguments.sortie), texte)
        print(f"Rapport écrit dans {arguments.sortie}")
    else:
        print(texte)
    return 0


def commande_importer(arguments: argparse.Namespace) -> int:
    resultat = charger_fichiers(arguments.fichiers, arguments.source)
    candidats = dedoublonnage.detecter(resultat.etablissements, seuil=arguments.seuil)
    resultat.doublons = [
        {
            "etablissement_a": c.a.nom,
            "etablissement_b": c.b.nom,
            "score": round(c.score, 2),
            "motifs": c.motifs,
        }
        for c in candidats
    ]

    if not arguments.base:
        print(
            "Aucune base fournie (--base) : import simulé. "
            "Les fiches validées seraient insérées/mises à jour ; "
            "les doublons détectés resteraient en attente d'arbitrage humain."
        )
    else:
        sql = generation.generer_sql(resultat.etablissements)
        appliquer_en_base(arguments.base, sql)
        enregistrer_lot(arguments.base, Path(arguments.fichiers[0]).name, arguments.format or "auto", resultat)
        print(f"{len(resultat.etablissements)} fiches appliquées en base.")

    rapport_lot = module_rapport.rapport_lot(
        nom_fichier=", ".join(Path(f).name for f in arguments.fichiers),
        format_fichier=arguments.format or "auto",
        total_lignes=resultat.total_lignes,
        ajoutees=len(resultat.etablissements),
        mises_a_jour=0,
        rejetees=resultat.rejets,
        doublons=resultat.doublons,
        a_verifier=resultat.a_verifier,
    )
    print(module_rapport.rapport_lot_markdown(rapport_lot))
    if arguments.rapport:
        generation.ecrire_fichier(
            Path(arguments.rapport), module_rapport.rapport_lot_markdown(rapport_lot)
        )
    return 0


def commande_exporter(arguments: argparse.Namespace) -> int:
    resultat = charger_fichiers(arguments.fichiers, arguments.source)
    if arguments.format == "csv":
        exporter_csv(resultat.etablissements, Path(arguments.sortie))
    else:
        contenu = generation.construire_catalogue(resultat.etablissements)
        generation.ecrire_fichier(Path(arguments.sortie), json.dumps(contenu, ensure_ascii=False, indent=1))
    print(f"{len(resultat.etablissements)} fiches exportées vers {arguments.sortie}")
    return 0


def construire_analyseur() -> argparse.ArgumentParser:
    analyseur = argparse.ArgumentParser(description="Catalogue national DEKK FOOD — import et contrôle.")
    sous_commandes = analyseur.add_subparsers(dest="commande", required=True)

    def ajouter_fichiers(parseur: argparse.ArgumentParser) -> None:
        parseur.add_argument("fichiers", nargs="+", help="Fichiers CSV, XLSX ou JSON à traiter.")
        parseur.add_argument("--source", help="Code de source (colonne `sources` de la base) si absente du fichier.")
        parseur.add_argument("--seuil", type=float, default=0.62, help="Seuil de similarité pour les doublons.")

    valider = sous_commandes.add_parser("valider", help="Contrôler champs obligatoires et cohérence.")
    ajouter_fichiers(valider)
    valider.set_defaults(fonction=commande_valider)

    doublons = sous_commandes.add_parser("dedoublonner", help="Détecter les doublons suspects.")
    ajouter_fichiers(doublons)
    doublons.set_defaults(fonction=commande_dedoublonner)

    generer = sous_commandes.add_parser("generer", help="Générer le catalogue de l'application et le seed SQL.")
    ajouter_fichiers(generer)
    generer.add_argument("--dossier", default=str(RACINE), help="Racine du dépôt.")
    generer.add_argument("--rapport", help="Chemin du rapport de couverture Markdown à produire.")
    generer.set_defaults(fonction=commande_generer)

    rapport = sous_commandes.add_parser("rapport", help="Rapport de couverture du recensement.")
    ajouter_fichiers(rapport)
    rapport.add_argument("--format", choices=["markdown", "json"], default="markdown")
    rapport.add_argument("--sortie", help="Fichier de sortie (sinon affichage console).")
    rapport.set_defaults(fonction=commande_rapport)

    importer = sous_commandes.add_parser("importer", help="Importer un lot (validation + doublons + application).")
    ajouter_fichiers(importer)
    importer.add_argument("--base", help="URL PostgreSQL cible. Sans cette option : simulation.")
    importer.add_argument("--format", dest="format", help="Format déclaré du lot (csv, xlsx, json).")
    importer.add_argument("--rapport", help="Chemin du rapport de lot à produire.")
    importer.set_defaults(fonction=commande_importer)

    exporter = sous_commandes.add_parser("exporter", help="Exporter le catalogue (CSV ou JSON).")
    ajouter_fichiers(exporter)
    exporter.add_argument("--format", dest="format", choices=["csv", "json"], default="csv")
    exporter.add_argument("--sortie", required=True)
    exporter.set_defaults(fonction=commande_exporter)

    return analyseur


def main(argv: list[str] | None = None) -> int:
    analyseur = construire_analyseur()
    arguments = analyseur.parse_args(argv)
    return int(arguments.fonction(arguments))


if __name__ == "__main__":
    raise SystemExit(main())
