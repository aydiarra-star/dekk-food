"""Tests de garde pour l'audit statique des migrations SQL."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from tools.catalogue.audit_migrations import MIGRATIONS, auditer

ROOT = Path(__file__).resolve().parents[2]


def test_audit_couvre_toutes_les_migrations_sql():
    fichiers = sorted(MIGRATIONS.glob("*.sql"))
    assert len(fichiers) >= 7
    lignes = [auditer(path) for path in fichiers]
    assert all(int(ligne["lignes"]) > 0 for ligne in lignes)
    assert all("public_qualifie" in ligne for ligne in lignes)


def test_audit_detecte_le_sql_dynamique_de_securite():
    migration = auditer(MIGRATIONS / "0003_securite_vues_admin.sql")
    assert int(migration["public_qualifie"]) > 0
    assert int(migration["public_dynamique"]) > 0
    assert int(migration["policies"]) > 0


def test_mode_strict_refuse_de_faire_croire_que_public_est_isole():
    resultat = subprocess.run(
        [sys.executable, str(ROOT / "tools/catalogue/audit_migrations.py"), "--strict"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert resultat.returncode == 2
    assert "adaptation nécessaire" in resultat.stdout
    assert "Aucune migration n'est modifiée ni exécutée." in resultat.stdout
