#!/usr/bin/env python3
"""Audit statique des migrations SQL avant toute isolation de schéma.

Ce script ne modifie jamais les migrations et ne prétend pas les rendre compatibles.
Il signale les références explicites au schéma public, le SQL dynamique qui vise
public.%I, les SECURITY DEFINER et les objets sensibles à examiner avant adaptation.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = ROOT / "supabase" / "migrations"
PATTERNS = {
    "public_qualifie": re.compile(r"\bpublic\s*\.", re.IGNORECASE),
    "public_dynamique": re.compile(
        r"(?:format\s*\([^;]{0,500}?public\s*\.\s*%I|public\s*\.\s*%I)",
        re.IGNORECASE | re.DOTALL,
    ),
    "security_definer": re.compile(r"\bsecurity\s+definer\b", re.IGNORECASE),
    "search_path": re.compile(r"\bset\s+search_path\b", re.IGNORECASE),
    "policies": re.compile(r"\bcreate\s+policy\b", re.IGNORECASE),
    "grants": re.compile(r"\b(?:grant|revoke)\b", re.IGNORECASE),
    "extensions": re.compile(r"\bcreate\s+extension\b", re.IGNORECASE),
}


def auditer(path: Path) -> dict[str, int | str]:
    sql = path.read_text(encoding="utf-8")
    result: dict[str, int | str] = {"migration": path.name}
    for name, pattern in PATTERNS.items():
        result[name] = len(pattern.findall(sql))
    result["lignes"] = len(sql.splitlines())
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--schema-cible",
        default="catalogue",
        help="schéma envisagé pour la future isolation (informatif, aucun SQL n'est réécrit)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="retourne 2 si une migration contient encore des références explicites à public",
    )
    args = parser.parse_args()

    files = sorted(MIGRATIONS.glob("*.sql"))
    if not files:
        parser.error(f"Aucune migration SQL trouvée dans {MIGRATIONS}")

    rows = [auditer(path) for path in files]
    columns = ["migration", "lignes", "public_qualifie", "public_dynamique",
               "security_definer", "search_path", "policies", "grants", "extensions"]
    print(f"Audit statique des migrations — schéma cible envisagé : {args.schema_cible}")
    print("Aucune migration n'est modifiée ni exécutée.")
    print(" | ".join(columns))
    for row in rows:
        print(" | ".join(str(row[col]) for col in columns))

    remaining = sum(int(row["public_qualifie"]) for row in rows)
    dynamic = sum(int(row["public_dynamique"]) for row in rows)
    print(f"TOTAL : {len(rows)} migrations ; {remaining} références lexicales à public. ; "
          f"{dynamic} motifs de SQL dynamique public.%I.")
    print("ATTENTION : décomptes lexicaux, non équivalents à une analyse syntaxique PostgreSQL.")
    if args.strict and remaining:
        print("ÉCHEC strict : références à public encore présentes ; adaptation nécessaire.")
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
