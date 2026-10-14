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
    RACINE / "supabase/migrations/0004_publication_validation_provenance.sql",
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
        "fiche publiée alors que l'information est indisponible",
        "update public.restaurants set est_publication_visible = true "
        "where niveau_verification = 'information_indisponible';",
        "restaurants_information_indisponible_check",
    ),
    (
        "fiche non publiée sans motif",
        "update public.restaurants set est_publication_visible = false, motif_non_publication = null "
        "where id = (select id from public.restaurants where est_publication_visible limit 1);",
        "restaurants_motif_non_publication_check",
    ),
    (
        "validation « validee » sans personne identifiée",
        "update public.restaurants set statut_validation = 'validee' limit 1;",
        "restaurants_validation_coherence_check",
    ),
    (
        "niveau « verifie » sans validation tracée",
        "update public.restaurants set niveau_verification = 'verifie' limit 1;",
        "restaurants_verifie_exige_validation_check",
    ),
    (
        "photo présentée comme authentique sans droits documentés",
        "insert into public.images (restaurant_id, url, correspondance_verifiee) "
        "select id, 'https://exemple.test/photo.jpg', true from public.restaurants limit 1;",
        "images_authentique_droits_check",
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

    # --- Validation humaine : un badge ne s'attribue que par un acte tracé -------
    ADMIN = "00000000-0000-0000-0000-0000000000a1"
    try:
        executer(
            "insert into public.utilisateurs_admin (id, email, role) "
            f"values ('{ADMIN}', 'admin@dekk.test', 'admin') on conflict (id) do nothing;"
        )
        cible = recuperer(
            "select id from public.restaurants where est_publication_visible "
            "order by numero_fiche nulls last limit 1;"
        )[0][0]

        def refus(description: str, sql: str, attendu: bool = True) -> None:
            """Vérifie qu'une requête est refusée (ou acceptée) et le signale."""
            nonlocal echecs
            try:
                executer(sql)
                accepte = True
            except Exception:
                accepte = False
            # attendu = True signifie « la base doit REFUSER cette requête ».
            if accepte != attendu:
                print(f"OK     {description} : {'accepté' if accepte else 'refusé'} comme attendu")
            else:
                print(f"ÉCHEC  {description} : {'accepté' if accepte else 'refusé'} alors qu'il devrait être "
                      f"{'accepté' if attendu else 'refusé'}")
                echecs += 1

        # Sans identité administrateur : aucun badge ne peut être attribué.
        executer("select set_config('dekkfood.utilisateur_id', '', false);")
        refus(
            "validation sans administrateur identifié",
            f"select public.valider_fiche_par_controle('{cible}', 'verifie', 'appel du 14/10/2026');",
        )

        executer(f"select set_config('dekkfood.utilisateur_id', '{ADMIN}', false);")
        refus(
            "validation sans preuve",
            f"select public.valider_fiche_par_controle('{cible}', 'verifie', '   ');",
        )
        refus(
            "validation vers un niveau interdit",
            f"select public.valider_fiche_par_controle('{cible}', 'information_indisponible', 'test');",
        )

        # Validation réelle : la fiche est marquée vérifiée ET traçable.
        executer(
            "select public.valider_fiche_par_controle("
            f"'{cible}', 'partiellement_verifie', 'appel du responsable le 14/10/2026', 'horaires confirmés');"
        )
        niveau, statut, valide_par, verif_le = recuperer(
            f"select niveau_verification, statut_validation, validation_par, derniere_verification_le "
            f"from public.restaurants where id = '{cible}';"
        )[0]
        if statut == "validee" and valide_par is not None and verif_le is not None:
            print(f"OK     validation tracée : niveau={niveau}, statut={statut}, validée par {valide_par}")
        else:
            print(f"ÉCHEC  validation non tracée : niveau={niveau}, statut={statut}, par={valide_par}")
            echecs += 1

        # Dévalidation : le badge est retiré et le motif conservé.
        executer(f"select public.devalider_fiche('{cible}', 'fermeture signalée à vérifier');")
        niveau, statut = recuperer(
            f"select niveau_verification, statut_validation from public.restaurants where id = '{cible}';"
        )[0]
        if statut == "non_validee" and niveau == "a_confirmer":
            print("OK     dévalidation tracée (retour à a_confirmer, statut non_validee)")
        else:
            print(f"ÉCHEC  dévalidation : niveau={niveau}, statut={statut}")
            echecs += 1

        # Une revendication ne vaut jamais vérification.
        refus(
            "revendication marquée vérifiée sans vérificateur identifié",
            "insert into public.revendications (restaurant_id, demandeur_nom, email_pro, statut) "
            f"select '{cible}', 'Responsable test', 'responsable@exemple.test', 'verifiee';",
        )
        refus(
            "rejet de revendication non motivé",
            "insert into public.revendications (restaurant_id, demandeur_nom, email_pro, statut) "
            f"select '{cible}', 'Responsable test', 'responsable@exemple.test', 'rejetee';",
        )

        # L'identité de session est remise à zéro après les contrôles.
        executer("select set_config('dekkfood.utilisateur_id', '', false);")
    except Exception as exc:  # noqa: BLE001
        print(f"ÉCHEC  contrôles de validation : {str(exc)[:600]}")
        echecs += 1

    # --- Parité de publication entre le catalogue embarqué et la base -----------
    try:
        import json as _json

        catalogue = _json.loads((RACINE / "assets/data/catalogue.json").read_text(encoding="utf-8"))
        non_publiees_catalogue = {f["slug"] for f in catalogue["etablissements"] if not f["est_publication_visible"]}
        non_publiees_base = {ligne[0] for ligne in recuperer(
            "select slug from public.restaurants where not est_publication_visible;")}
        if non_publiees_catalogue == non_publiees_base:
            print(f"OK     publication identique dans le catalogue et la base "
                  f"({len(non_publiees_catalogue)} fiche(s) non publiée(s), conservée(s) des deux côtés)")
        else:
            print(f"ÉCHEC  divergence de publication : catalogue seul "
                  f"{sorted(non_publiees_catalogue - non_publiees_base)}, base seule "
                  f"{sorted(non_publiees_base - non_publiees_catalogue)}")
            echecs += 1
    except Exception as exc:  # noqa: BLE001
        print(f"ÉCHEC  parité de publication : {str(exc)[:600]}")
        echecs += 1

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
