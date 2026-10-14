"""Tests du ciblage explicite du schéma pour les seeds SQL."""
from __future__ import annotations

import pytest

from tools.catalogue.schema_sql import qualifier_schema_sql


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
