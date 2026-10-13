#!/usr/bin/env python3
"""Vérification de bout en bout de la base DEKK FOOD sur un PostgreSQL réel.

Le script démarre une instance PostgreSQL jetable (pgserver), applique :
  1. supabase/schema.sql (base existante, conservée)
  2. les trois migrations
  3. le référentiel national (14 régions, 46 départements)
  4. le seed du catalogue généré par tools/catalogue
puis rejoue le seed (idempotence), interroge les vues d'administration et
vérifie que les contraintes de qualité REFUSENT bien les données interdites.

Usage :
    python tools/tests/verifier_schema_postgres.py
    pytest tools/tests/verifier_schema_postgres.py     (test facultatif)
"""

from __future__ import annotations

import pathlib
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parents[2]

# Le dépôt doit être importable même lorsque le script est lancé depuis son dossier :
# la parité des doublons est contrôlée contre le pipeline Python tools/catalogue.
sys.path.insert(0, str(RACINE))

FICHIERS = [
    RACINE / "supabase/schema.sql",
    RACINE / "supabase/migrations/0001_referentiel_et_catalogue.sql",
    RACINE / "supabase/migrations/0002_menus_images_services.sql",
    RACINE / "supabase/migrations/0003_securite_vues_admin.sql",
    RACINE / "supabase/seed/00_referentiel.sql",
]

# Insertions qui DOIVENT être refusées par les contraintes du schéma.
INSERTIONS_INTERDITES = [
    (
        "prix confirmé sans source",
        "insert into public.plats (restaurant_id, nom, prix, statut_confirmation) "
        "select id, 'plat test', 1000, 'confirme' from public.restaurants limit 1;",
        "plats_prix_source_check",
    ),
    (
        "image générique présentée comme authentique",
        "insert into public.images (restaurant_id, url, est_illustration_generique, correspondance_verifiee) "
        "select id, 'https://exemple.test/x.jpg', true, true from public.restaurants limit 1;",
        "images_generique_coherence",
    ),
    (
        "propriétaire confirmé sans source",
        "insert into public.entreprises (raison_sociale, statut_confirmation) values ('Société test', 'confirme');",
        "entreprises_source_obligatoire",
    ),
    (
        "fiche publiée sans région",
        "insert into public.restaurants (name, cuisine_type, neighborhood, est_publication_visible) "
        "values ('Test sans région', 'x', 'y', true);",
        "restaurants_publication_localisation_check",
    ),
    (
        "zone de livraison confirmée sans source",
        "insert into public.zones_livraison (restaurant_id, libelle_zone, confirme) "
        "select id, 'Test', true from public.restaurants limit 1;",
        "zones_livraison_source_check",
    ),
    (
        "compte restaurateur sans établissement",
        "insert into public.utilisateurs_admin (id, email, role) "
        "values (gen_random_uuid(), 'resto@test.sn', 'restaurateur');",
        "utilisateurs_admin_restaurateur_check",
    ),
]


def _demarrer_instance():
    """Démarre une instance PostgreSQL jetable et renvoie un curseur psycopg.

    psycopg est utilisé (et non l'utilitaire psql) car il LÈVE une exception dès
    qu'une instruction SQL échoue : sans cela, un script pourrait « réussir » en
    n'appliquant rien du tout.
    """
    try:
        import pgserver  # type: ignore
        import psycopg  # type: ignore
    except ImportError:  # pragma: no cover
        print("pgserver/psycopg non installés : vérification SQL ignorée "
              "(pip install -r tools/requirements.txt).")
        return None
    serveur = pgserver.get_server(tempfile.mkdtemp())
    connexion = psycopg.connect(serveur.get_uri(), autocommit=True)
    connexion.autocommit = True
    return connexion


def executer_verifications() -> int:
    base = _demarrer_instance()
    if base is None:
        return 0

    def executer(sql: str) -> None:
        with base.cursor() as curseur:
            curseur.execute(sql)

    def interroger(sql: str) -> str:
        with base.cursor() as curseur:
            curseur.execute(sql)
            lignes = curseur.fetchall()
        return "\n".join(" | ".join(str(c) for c in ligne) for ligne in lignes) or "(aucune ligne)"

    def recuperer(sql: str):
        with base.cursor() as curseur:
            curseur.execute(sql)
            return curseur.fetchall()

    echecs = 0
    for fichier in FICHIERS:
        try:
            executer(fichier.read_text(encoding="utf-8"))
            print(f"OK     application de {fichier.name}")
        except Exception as exc:  # noqa: BLE001
            print(f"ÉCHEC  application de {fichier.name} : {str(exc)[:1200]}")
            return 1

    seed = RACINE / "supabase/seed/10_etablissements.sql"
    if seed.exists():
        contenu = seed.read_text(encoding="utf-8")
        for passe in (1, 2):
            suffixe = ", contrôle d'idempotence" if passe == 2 else ""
            try:
                executer(contenu)
                print(f"OK     seed du catalogue (passe {passe}{suffixe})")
            except Exception as exc:  # noqa: BLE001
                print(f"ÉCHEC  seed du catalogue (passe {passe}) : {str(exc)[:1200]}")
                return 1

    controles = {
        "régions": "select count(*) from public.regions;",
        "départements": "select count(*) from public.departements;",
        "fiches": "select count(*) from public.restaurants;",
        "fiches publiées": "select count(*) from public.restaurants where est_publication_visible;",
        "doublons détectés": "select public.detecter_doublons(0.62, 150);",
        "qualité": ("select fiches_total, fiches_publiees, fiches_adresse_confirmee, "
                    "fiches_obsoletes from public.v_qualite_catalogue;"),
        "régions couvertes": ("select region, fiches from public.v_couverture_par_region "
                              "where fiches > 0 order by fiches desc;"),
    }
    for nom, requete in controles.items():
        try:
            print(f"--- {nom} ---\n{interroger(requete)[:700]}")
        except Exception as exc:  # noqa: BLE001
            print(f"ÉCHEC  {nom} : {str(exc)[:600]}")
            echecs += 1

    # --- Aucune fiche ne doit disparaître entre le catalogue et la base
    try:
        import json as _json

        catalogue = _json.loads((RACINE / "assets/data/catalogue.json").read_text(encoding="utf-8"))
        attendues = len(catalogue["etablissements"])
        presentes = recuperer("select count(*) from public.restaurants;")[0][0]
        total_slugs, slugs_distincts = recuperer(
            "select count(*), count(distinct slug) from public.restaurants;"
        )[0]
        if attendues != presentes:
            print(f"ÉCHEC  fiches perdues à l'amorçage : {attendues} au catalogue, {presentes} en base")
            echecs += 1
        elif total_slugs != slugs_distincts:
            print(f"ÉCHEC  slugs dupliqués en base : {total_slugs} fiches pour {slugs_distincts} slugs")
            echecs += 1
        else:
            print(f"OK     les {presentes} fiches du catalogue sont toutes en base, slugs uniques")
    except Exception as exc:  # noqa: BLE001
        print(f"ÉCHEC  contrôle catalogue/base : {str(exc)[:600]}")
        echecs += 1

    # --- Parité des doublons détectés entre la base (SQL) et le pipeline (Python)
    try:
        import json as _json
        from glob import glob as _glob

        from tools.catalogue import dedoublonnage as _dedup
        from tools.catalogue.modele import Etablissement as _Etablissement

        fiches = []
        for fichier in sorted(_glob("data/seed/*.json")):
            with open(fichier, encoding="utf-8") as flux:
                fiches.extend(_Etablissement.depuis_dict(brut) for brut in _json.load(flux)["etablissements"])
        paires_python = {tuple(sorted((paire.a.nom, paire.b.nom))) for paire in _dedup.detecter(fiches)}
        paires_sql = {
            tuple(sorted((ligne[0], ligne[1])))
            for ligne in recuperer(
                "select a.name, b.name from public.doublons_suspects d "
                "join public.restaurants a on a.id = d.restaurant_a "
                "join public.restaurants b on b.id = d.restaurant_b;"
            )
        }
        print(f"--- doublons Python ({len(paires_python)}) ---\n" + "\n".join(f" - {a} ⇄ {b}" for a, b in sorted(paires_python)))
        print(f"--- doublons SQL ({len(paires_sql)}) ---\n" + "\n".join(f" - {a} ⇄ {b}" for a, b in sorted(paires_sql)))
        if paires_python != paires_sql:
            print(f"ÉCHEC  parité des doublons : Python seul {sorted(paires_python - paires_sql)}, SQL seul {sorted(paires_sql - paires_python)}")
            echecs += 1
        else:
            print("OK     les doublons détectés par la base et par le pipeline Python coïncident")
    except Exception as exc:  # noqa: BLE001
        print(f"ÉCHEC  parité des doublons : {str(exc)[:600]}")
        echecs += 1

    for nom, requete, contrainte in INSERTIONS_INTERDITES:
        try:
            executer(requete)
            print(f"ÉCHEC  {nom} : insertion acceptée alors qu'elle doit être refusée ({contrainte})")
            echecs += 1
        except Exception:
            print(f"OK     refusé par la base : {nom}")

    return 1 if echecs else 0


def test_schema_postgres() -> None:  # pragma: no cover - nécessite pgserver
    """Point d'entrée pytest (ignoré si pgserver est absent)."""
    import pytest

    try:
        import pgserver  # noqa: F401
    except ImportError:
        pytest.skip("pgserver non installé")

    assert executer_verifications() == 0


if __name__ == "__main__":
    raise SystemExit(executer_verifications())
