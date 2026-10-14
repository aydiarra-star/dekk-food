"""Contrat statique des tables référencées par le générateur du seed catalogue.

Ce test garde l'inventaire de dépendances synchronisé avec le code source.
Il ne prouve pas que le DDL d'un schéma cible existe ni que les migrations sont isolées.
"""
from __future__ import annotations

import pathlib
import re

RACINE = pathlib.Path(__file__).resolve().parents[2]
GENERATEUR = RACINE / "tools/catalogue/generation.py"

# Références littérales du générateur, y compris celles présentes dans les
# fragments SQL assemblés. Toute nouvelle dépendance exige une revue du contrat.
TABLES_ATTENDUES = {
    "allergenes",
    "categories_culinaires",
    "communes",
    "contacts",
    "departements",
    "entreprises",
    "etablissement_categories",
    "etablissement_exploitation",
    "etablissement_services",
    "etablissement_sources",
    "horaires",
    "images",
    "menus",
    "plat_allergenes",
    "plat_regimes",
    "plats",
    "quartiers",
    "regimes_alimentaires",
    "regions",
    "restaurants",
    "services",
    "sources",
    "types_etablissement",
    "zones_livraison",
}


def test_inventaire_des_tables_du_generateur_est_explicite() -> None:
    source = GENERATEUR.read_text(encoding="utf-8")
    references = set(re.findall(r"public\.([a-z_][a-z0-9_]*)", source, flags=re.IGNORECASE))

    assert references == TABLES_ATTENDUES, (
        "Les références SQL du générateur ont changé. Réviser "
        "docs/CONTRAT_CATALOGUE_ISOLE.md et les migrations dédiées avant "
        "d'accepter ce changement. "
        f"Nouvelles références: {sorted(references - TABLES_ATTENDUES)}; "
        f"références disparues: {sorted(TABLES_ATTENDUES - references)}"
    )


def test_qualificateur_de_seed_ne_vaut_pas_migration_isolee() -> None:
    source = (RACINE / "tools/catalogue/schema_sql.py").read_text(encoding="utf-8")
    assert "ne crée aucun objet SQL" in source
    assert "pas un parseur SQL" in source
