"""Tests du pipeline de catalogue (exécutables sans base de données).

Ces tests protègent les règles du cahier des charges : aucune donnée sans
source, aucun prix confirmé sans source, aucun propriétaire déduit d'un nom,
aucune source inconnue du référentiel SQL, et contrat de données stable entre le
générateur Python et l'application Flutter.

Exécution : python3 -m pytest tools/tests/test_catalogue_pipeline.py -q
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

from tools.catalogue import dedoublonnage, normalisation, rapport
from tools.catalogue.modele import Etablissement

RACINE = Path(__file__).resolve().parents[2]
SEEDS = sorted((RACINE / "data" / "seed").glob("*.json"))
CATALOGUE = RACINE / "assets" / "data" / "catalogue.json"
REFERENTIEL_SQL = RACINE / "supabase" / "seed" / "00_referentiel.sql"


def charger_fiches() -> list[Etablissement]:
    fiches = []
    for fichier in SEEDS:
        donnees = json.loads(fichier.read_text(encoding="utf-8"))
        for brut in donnees.get("etablissements", []):
            fiches.append(Etablissement.depuis_dict(brut))
    return fiches


def test_seeds_presents() -> None:
    assert len(SEEDS) >= 4, f"fichiers de collecte attendus, trouvés : {len(SEEDS)}"
    fiches = charger_fiches()
    assert len(fiches) >= 100, f"catalogue trop maigre : {len(fiches)} fiches"


def test_aucune_fiche_sans_source_ni_date() -> None:
    for fiche in charger_fiches():
        assert fiche.sources, f"{fiche.nom} n'a aucune source"
        assert any(source.date_collecte for source in fiche.sources), f"{fiche.nom} n'a aucune date de collecte"


def test_aucun_prix_confirme_sans_source() -> None:
    for fiche in charger_fiches():
        for menu in fiche.menus:
            for plat in menu.plats:
                if plat.statut_confirmation == "confirme" and plat.prix is not None:
                    assert plat.source or plat.source_url or menu.source or menu.source_url, (
                        f"Prix « {plat.nom} » de {fiche.nom} marqué confirmé sans source"
                    )


def test_proprietaire_jamais_deduit_dun_nom() -> None:
    for fiche in charger_fiches():
        for exploitation in fiche.exploitation:
            if exploitation.statut_confirmation == "confirme":
                assert exploitation.source_url or exploitation.source, (
                    f"Exploitant de {fiche.nom} marqué confirmé sans source"
                )
            assert exploitation.libelle != fiche.nom or exploitation.role in {"exploitant", "proprietaire"}


def test_images_generiques_signalees() -> None:
    for fiche in charger_fiches():
        for image in fiche.toutes_les_images:
            if image.est_illustration_generique:
                assert image.legende, f"Image générique sans légende sur {fiche.nom}"
                assert image.licence, f"Image générique sans licence documentée sur {fiche.nom}"


def test_codes_de_source_enregistres_dans_le_referentiel() -> None:
    referentiel = REFERENTIEL_SQL.read_text(encoding="utf-8")
    codes_connus = set(re.findall(r"^\s*\('([a-z_]+)',", referentiel, flags=re.MULTILINE))
    for fiche in charger_fiches():
        for source in fiche.sources:
            assert source.code in codes_connus, (
                f"Source « {source.code} » utilisée par {fiche.nom} mais absente de 00_referentiel.sql "
                "(à enregistrer dans public.sources)"
            )


def test_detection_de_doublons_ne_fusionne_jamais_automatiquement() -> None:
    fiches = charger_fiches()
    paires = dedoublonnage.detecter(fiches)
    assert isinstance(paires, list)
    for paire in paires:
        assert 0.5 <= paire.score <= 1.0, paire.resume()
        assert paire.a.cle != paire.b.cle


def test_normalisation_des_numeros_senegalais() -> None:
    assert normalisation.normaliser_telephone("+221 33 864 92 92") == "+221338649292"
    assert normalisation.normaliser_telephone("77 461 51 16") == "+221774615116"
    assert normalisation.normaliser_telephone("774615116") == "+221774615116"
    assert normalisation.normaliser_telephone("sans numéro") is None
    assert normalisation.normaliser_telephone("") is None
    assert normalisation.normaliser_whatsapp("+221 78 306 80 80") == "+221783068080"


def test_contrat_de_donnees_avec_lapplication_flutter() -> None:
    """Le catalogue généré doit contenir les champs lus par lib/models/catalogue.dart."""
    assert CATALOGUE.exists(), "assets/data/catalogue.json doit être généré"
    donnees = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    champs_fiche = {
        "id",
        "cle",
        "slug",
        "nom",
        "nom_officiel",
        "type_etablissement",
        "type_libelle",
        "categories",
        "categories_libelles",
        "statut",
        "niveau_verification",
        "region",
        "departement",
        "commune",
        "quartier",
        "quartier_libre",
        "adresse",
        "latitude",
        "longitude",
        "gps_verifie",
        "telephone",
        "whatsapp",
        "site_web",
        "services",
        "horaires",
        "zones_livraison",
        "images",
        "image_principale_url",
        "menus",
        "exploitation",
        "sources",
        "date_collecte",
        "derniere_verification_le",
    }
    for fiche in donnees["etablissements"]:
        manquants = champs_fiche - set(fiche)
        assert not manquants, f"champs absents de la fiche {fiche.get('id')} : {sorted(manquants)}"
        for source in fiche["sources"]:
            assert {"source", "url"}.issubset(source), source


def test_rapport_de_couverture_mesure_les_manques() -> None:
    donnees = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    fiches = charger_fiches()
    assert len(donnees["etablissements"]) == len(fiches), "le catalogue publié doit refléter les fichiers de collecte"
    couverture = rapport.rapport_couverture(fiches)
    assert couverture["total_fiches"] == len(fiches)
    assert couverture["regions_couvertes"], "aucune région mesurée"
    # Matam est couverte depuis le 13/10/2026 (relevé OpenStreetMap à Ourossogui) :
    # les 14 régions sont représentées, mais la couverture reste partielle et inégale.
    assert len(couverture["regions_couvertes"]) == 14, (
        "les 14 régions doivent être représentées dans le catalogue"
    )
    assert "Matam" in couverture["regions_couvertes"], "la région de Matam doit être mesurée"
    # Le référentiel compte 46 départements : la collecte doit rester mesurablement
    # incomplète à cette échelle, et le rapport doit continuer à le publier.
    # La couverture reste très partielle : la mesure des manques doit rester publiée.
    assert couverture["qualite"]["horaires"] < couverture["total_fiches"], (
        "le rapport doit continuer à mesurer les données manquantes (horaires)"
    )
    qualite = couverture["qualite"]
    assert qualite["avec_source"] == len(fiches)
    assert qualite["gps_verifie"] == 0, "aucune position n'a été vérifiée sur place à ce stade"
    assert couverture["limites"], "les limites de la collecte doivent être documentées"



def test_aucun_slug_duplique_dans_le_catalogue() -> None:
    """Deux fiches au même slug s'écraseraient lors de l'amorçage : c'est interdit."""
    donnees = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    slugs = [etablissement["slug"] for etablissement in donnees["etablissements"] if etablissement.get("slug")]
    doublons = sorted({slug for slug in slugs if slugs.count(slug) > 1})
    assert not doublons, f"slugs dupliqués dans le catalogue : {doublons}"


# --------------------------------------------------------------------------- #
# Publication : règle explicite, sans perte de données
# --------------------------------------------------------------------------- #
def test_publication_regle_appliquee_et_motifs_explicites() -> None:
    """Une fiche n'est publiée que si la règle est satisfaite, sinon elle porte un motif."""
    donnees = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    fiches = donnees["etablissements"]
    assert fiches, "catalogue vide"

    for fiche in fiches:
        publiee = fiche["est_publication_visible"]
        if publiee:
            assert fiche.get("region"), f"publiée sans région : {fiche['id']}"
            assert fiche.get("sources"), f"publiée sans source : {fiche['id']}"
            assert fiche.get("niveau_verification") != "information_indisponible", (
                f"publiée alors que l'information est indisponible : {fiche['id']}"
            )
        else:
            assert fiche.get("motif_non_publication"), (
                f"fiche non publiée sans motif : {fiche['id']} — rien ne doit être écarté en silence"
            )

    synthese = donnees["couverture"]["publication"]
    assert synthese["fiches_publiees"] + synthese["fiches_non_publiees"] == len(fiches), (
        "le décompte de publication doit couvrir toutes les fiches"
    )
    assert synthese["regle"], "la règle de publication doit être publiée avec le catalogue"


def test_aucune_fiche_perdue_par_la_publication() -> None:
    """Non publiée ne veut pas dire supprimée : la fiche reste dans le catalogue et dans les seeds."""
    donnees = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    fiches = charger_fiches()
    assert len(donnees["etablissements"]) == len(fiches), (
        "le catalogue publié doit contenir exactement les fiches collectées"
    )
    non_publiees = [f for f in donnees["etablissements"] if not f["est_publication_visible"]]
    assert non_publiees, "le jeu de données de référence contient des fiches écartées : elles doivent rester visibles"
    for fiche in non_publiees:
        assert fiche["nom"], "une fiche non publiée perd son nom"
        assert fiche["sources"], "une fiche non publiée perd ses sources (traçabilité exigée)"


def test_publication_non_elargie_par_la_regle() -> None:
    """La règle ne peut que restreindre l'intention exprimée par le fichier de collecte."""
    for etablissement in charger_fiches():
        decision = etablissement.publication
        if decision.visible:
            assert etablissement.est_publication_visible, (
                f"{etablissement.nom} : la règle a élargi la publication au-delà du fichier de collecte"
            )


def test_validation_distincte_de_la_publication() -> None:
    """« Publiée » n'est pas « vérifiée » : aucune fiche n'est validée par un humain à ce stade."""
    donnees = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    for fiche in donnees["etablissements"]:
        assert fiche["statut_validation"] in {"non_validee", "en_cours", "validee", "rejetee"}
        if fiche["statut_validation"] == "validee":
            assert fiche.get("validation_par") and fiche.get("validation_le"), (
                f"validation anonyme sur {fiche['id']} : une validation exige une personne et une date"
            )
        if fiche["niveau_verification"] == "verifie":
            assert fiche["statut_validation"] == "validee", (
                f"{fiche['id']} est « vérifiée » sans validation tracée"
            )


# --------------------------------------------------------------------------- #
# Provenance et autorisation d'image
# --------------------------------------------------------------------------- #
def test_provenance_exposee_pour_chaque_fiche() -> None:
    donnees = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    for fiche in donnees["etablissements"]:
        provenance = fiche.get("provenance")
        assert provenance, f"provenance absente sur {fiche['id']}"
        assert provenance["nombre_sources"] == len(fiche["sources"]), (
            f"décompte de sources incohérent sur {fiche['id']}"
        )
        assert provenance["methode"], f"méthode de collecte non documentée sur {fiche['id']}"
        # Une vérification humaine n'est jamais présumée.
        assert provenance["verification_humaine"] == bool(fiche.get("derniere_verification_le"))


def test_autorisation_image_jamais_presumee() -> None:
    donnees = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    for fiche in donnees["etablissements"]:
        synthese = fiche["autorisation_image"]
        assert synthese["nombre_images"] == len(fiche["images"])
        if synthese["nombre_images"] == 0:
            assert synthese["statut"] == "aucune_image"
            assert synthese["autorisation_ecrite_restaurant"] is False
        if synthese["images_sans_droits_documentes"]:
            assert synthese["statut"] in {"droits_partiels", "illustrations_generiques_seulement"}, (
                f"{fiche['id']} : des images sans droits ne peuvent pas être déclarées documentées"
            )
        for image in fiche["images"]:
            if image["est_illustration_generique"]:
                assert image["correspondance_verifiee"] is False, (
                    f"{fiche['id']} : une illustration générique ne peut pas être présentée comme authentique"
                )
            if image["correspondance_verifiee"]:
                droits = (
                    image.get("auteur")
                    or image.get("licence")
                    or image.get("autorisation_usage")
                    or image.get("autorisation_reference")
                )
                assert droits, f"{fiche['id']} : photo authentique sans droits documentés"


# --------------------------------------------------------------------------- #
# Données confirmées : jamais sans source
# --------------------------------------------------------------------------- #
def test_aucune_donnee_confirmee_sans_source() -> None:
    """Tout élément marqué confirmé doit citer sa source : on ne confirme rien d'office."""
    donnees = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    for fiche in donnees["etablissements"]:
        sources = fiche.get("sources") or []
        for contact in fiche.get("contacts") or []:
            if contact.get("confirme"):
                assert contact.get("source"), f"{fiche['id']} : contact confirmé sans source"
        for service in fiche.get("services") or []:
            if service.get("confirme"):
                assert sources, f"{fiche['id']} : service confirmé sans aucune source"
        for image in fiche.get("images") or []:
            if image.get("correspondance_verifiee"):
                assert image.get("source") or image.get("licence") or image.get("autorisation_usage"), (
                    f"{fiche['id']} : image authentique sans source ni droits"
                )
        for plat in [p for m in fiche.get("menus") or [] for p in m.get("plats") or []]:
            if plat.get("statut_confirmation") == "confirme":
                assert plat.get("prix") is not None, (
                    f"{fiche['id']} : plat confirmé sans prix — un prix vide ne se confirme pas"
                )


def test_les_doublons_ne_sont_jamais_fusionnes_automatiquement() -> None:
    """Le dédoublonnage propose, l'humain décide : les deux fiches restent dans le catalogue."""
    fiches = charger_fiches()
    donnees = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    noms = {fiche["nom"] for fiche in donnees["etablissements"]}
    paires = dedoublonnage.detecter(fiches)
    examines = 0
    for paire in paires:
        if paire.a.nom in noms and paire.b.nom in noms:
            examines += 1
    assert examines >= 1, "le jeu de référence contient des paires suspectes : elles doivent rester soumises à examen"
    assert len(donnees["etablissements"]) == len(fiches), (
        "aucune fusion automatique ne doit avoir lieu : le nombre de fiches doit être identique"
    )

if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(pytest.main([__file__, "-q"]))
