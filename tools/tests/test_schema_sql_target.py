"""Tests du ciblage explicite du schéma pour les seeds SQL."""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from tools.catalogue import generation
from tools.catalogue.modele import Etablissement
from tools.catalogue.schema_sql import qualifier_schema_sql

RACINE = Path(__file__).resolve().parents[2]
SEED = sorted((RACINE / "data" / "seed").glob("*.json"))[0]


def _premiere_fiche():
    donnees = json.loads(SEED.read_text(encoding="utf-8"))
    return Etablissement.depuis_dict(donnees["etablissements"][0])


def test_generateur_expose_schema_cible_sans_changer_la_cible_par_defaut():
    fiche = _premiere_fiche()
    sql_historique = generation.generer_sql([fiche])
    sql_isole = generation.generer_sql([fiche], schema_cible="catalogue")

    assert "insert into public.restaurants" in sql_historique
    assert "insert into catalogue.restaurants" in sql_isole
    assert "public." not in sql_isole
    assert "catalogue.sources" in sql_isole


def test_schema_public_reste_strictement_inchange():
    sql = "insert into public.restaurants values (1); select * from public.sources;"
    assert qualifier_schema_sql(sql) == sql
    assert qualifier_schema_sql(sql, "public") == sql


def test_schema_cible_remplace_les_qualificateurs_sql():
    sql = (
        "insert into public.restaurants values (1); "
        "select * from public.sources; "
        "select public.contacts.source_url;"
    )
    attendu = (
        "insert into catalogue.restaurants values (1); "
        "select * from catalogue.sources; "
        "select catalogue.contacts.source_url;"
    )
    assert qualifier_schema_sql(sql, "catalogue") == attendu


@pytest.mark.parametrize("schema", ["", "Public", "public; drop schema public", "catalogue.x", "1schema", "a" * 64])
def test_schema_cible_invalide_est_refuse(schema):
    with pytest.raises(ValueError):
        qualifier_schema_sql("select 1;", schema)


def test_qualificateurs_deja_qualifies_ne_sont_pas_requalifies():
    sql = "select other.restaurants.id, public.restaurants.id from other.restaurants;"
    assert qualifier_schema_sql(sql, "catalogue") == (
        "select other.restaurants.id, catalogue.restaurants.id from other.restaurants;"
    )

def test_ne_modifie_pas_les_chaines_ou_commentaires_sql():
    sql = (
        "select public.restaurants.id, 'https://example.test/public.example' as url; "
        "-- public.ne_pas_remplacer\n"
        "/* public.non_plus */ select 1;"
    )
    resultat = qualifier_schema_sql(sql, "catalogue")
    assert "select catalogue.restaurants.id" in resultat
    assert "'https://example.test/public.example'" in resultat
    assert "-- public.ne_pas_remplacer" in resultat
    assert "/* public.non_plus */" in resultat
