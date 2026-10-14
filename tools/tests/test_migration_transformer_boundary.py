"""Barrière : le qualificateur de seed n'est pas un transformateur de migrations."""
from pathlib import Path

from tools.catalogue.schema_sql import qualifier_schema_sql

ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = ROOT / "supabase" / "migrations"


def test_qualificateur_de_seed_ne_transforme_pas_le_sql_dynamique_des_migrations():
    sql = (MIGRATIONS / "0003_securite_vues_admin.sql").read_text(encoding="utf-8")
    transforme = qualifier_schema_sql(sql, "catalogue")

    # Les références SQL normales sont requalifiées, mais les chaînes/dollar-quotes
    # contenant le SQL dynamique restent volontairement intactes.
    assert "create table if not exists catalogue.utilisateurs_admin" in transforme
    assert "execute format('alter table public.%I enable row level security'" in transforme
    assert "create policy" in transforme
    # Une transformation superficielle laisserait donc des policies ciblant public.
    assert "on public.%I" in transforme


def test_audit_documente_les_dependances_dynamiques_connues():
    doc = (ROOT / "docs" / "DEPENDANCES_CRITIQUES_SCHEMA_CATALOGUE.md").read_text(
        encoding="utf-8"
    )
    assert "0003_securite_vues_admin.sql" in doc
    assert "0005_cloisonnement_public.sql" in doc
    assert "ne doit **pas** être réutilisé comme transformateur général" in doc
