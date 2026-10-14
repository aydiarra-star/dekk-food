"""Harness d’intégration pour prouver l’isolation des migrations du catalogue.

Le harness démarre un PostgreSQL jetable. Il ne lit aucune variable DATABASE_URL et
n’accepte aucune cible réseau : la fixture historique et les migrations sont des
fichiers locaux explicitement fournis. Il refuse de fonctionner sans les deux.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import tempfile
from pathlib import Path
from typing import Any


def _snapshot_public(conn: Any) -> dict[str, Any]:
    """Empreinte des relations publiques, colonnes, contraintes et lignes."""
    result: dict[str, Any] = {"relations": {}, "functions": []}
    with conn.cursor() as cur:
        cur.execute("""
            select c.relname, c.relkind
            from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm', 'f')
            order by c.relname
        """)
        relations = cur.fetchall()
        for name, kind in relations:
            cur.execute("""
                select a.attname, format_type(a.atttypid, a.atttypmod), a.attnotnull,
                       pg_get_expr(d.adbin, d.adrelid)
                from pg_attribute a
                left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
                join pg_class c on c.oid = a.attrelid
                join pg_namespace n on n.oid = c.relnamespace
                where n.nspname = 'public' and c.relname = %s
                  and a.attnum > 0 and not a.attisdropped
                order by a.attnum
            """, (name,))
            columns = cur.fetchall()
            cur.execute("""
                select conname, contype, pg_get_constraintdef(oid, true)
                from pg_constraint
                where conrelid = (select c.oid from pg_class c
                                  join pg_namespace n on n.oid = c.relnamespace
                                  where n.nspname = 'public' and c.relname = %s)
                order by conname
            """, (name,))
            constraints = cur.fetchall()
            cur.execute("""
                select indexname, indexdef from pg_indexes
                where schemaname = 'public' and tablename = %s order by indexname
            """, (name,))
            indexes = cur.fetchall()
            rows = []
            if kind in ("r", "p"):
                quoted = '"' + name.replace('"', '""') + '"'
                cur.execute(f"select to_jsonb(t) from public.{quoted} as t")
                rows = [json.dumps(row[0], sort_keys=True, ensure_ascii=False, default=str)
                        for row in cur.fetchall()]
                rows.sort()
            payload = {
                "kind": kind,
                "columns": columns,
                "constraints": constraints,
                "indexes": indexes,
                "row_count": len(rows) if kind in ("r", "p") else None,
                "rows_sha256": hashlib.sha256("\n".join(rows).encode()).hexdigest()
                    if kind in ("r", "p") else None,
            }
            result["relations"][name] = json.loads(json.dumps(payload, default=str))
        cur.execute("""
            select p.proname, pg_get_function_identity_arguments(p.oid),
                   pg_get_functiondef(p.oid)
            from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' order by p.proname, 2
        """)
        result["functions"] = cur.fetchall()
    return json.loads(json.dumps(result, sort_keys=True, default=str))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--historical-fixture", type=Path, required=True,
                        help="SQL de fixture historique fidèle, uniquement pour PostgreSQL jetable.")
    parser.add_argument("--catalogue-migrations", type=Path, required=True,
                        help="Répertoire contenant exclusivement les migrations dédiées au catalogue.")
    args = parser.parse_args()
    fixture = args.historical_fixture.resolve()
    migration_dir = args.catalogue_migrations.resolve()
    if not fixture.is_file():
        parser.error(f"Fixture historique introuvable : {fixture}")
    migrations = sorted(migration_dir.glob("*.sql")) if migration_dir.is_dir() else []
    if not migrations:
        parser.error(f"Aucune migration catalogue dédiée trouvée dans {migration_dir}; aucune validation ne peut être revendiquée.")
    try:
        import pgserver  # type: ignore
        import psycopg  # type: ignore
    except ImportError as exc:
        parser.error(f"Installer les dépendances de test pgserver et psycopg : {exc}")
    server = pgserver.get_server(tempfile.mkdtemp(prefix="dekk-catalogue-isolation-"))
    conn = psycopg.connect(server.get_uri(), autocommit=True)
    try:
        with conn.cursor() as cur:
            cur.execute(fixture.read_text(encoding="utf-8"))
        before = _snapshot_public(conn)
        for migration in migrations:
            print(f"Application jetable : {migration.name}")
            with conn.cursor() as cur:
                cur.execute(migration.read_text(encoding="utf-8"))
        after = _snapshot_public(conn)
        if before != after:
            before_relations = set(before["relations"])
            after_relations = set(after["relations"])
            print("ÉCHEC : le contenu ou les objets du schéma public ont changé.")
            print("Relations ajoutées :", sorted(after_relations - before_relations))
            print("Relations supprimées :", sorted(before_relations - after_relations))
            changed = sorted(name for name in before_relations & after_relations
                             if before["relations"][name] != after["relations"][name])
            print("Relations modifiées :", changed)
            if before["functions"] != after["functions"]:
                print("Les fonctions du schéma public ont changé.")
            return 1
        print(f"SUCCÈS : {len(migrations)} migration(s) exécutée(s) sur PostgreSQL jetable ; empreinte public inchangée.")
        print("Cette preuve porte uniquement sur la fixture fournie et ne remplace pas les tests RLS/grants par rôle.")
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    raise SystemExit(main())



def test_snapshot_detecte_une_modification_des_donnees_historiques():
    try:
        import pgserver  # type: ignore
        import psycopg  # type: ignore
    except ImportError as exc:
        raise AssertionError(f"Les tests du harness exigent pgserver et psycopg : {exc}") from exc
    server = pgserver.get_server(tempfile.mkdtemp(prefix="dekk-harness-snapshot-"))
    with psycopg.connect(server.get_uri(), autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                create table public.restaurants (
                    id integer primary key,
                    name text not null
                );
                insert into public.restaurants values (42, 'Fiche historique témoin');
                create function public.fonction_historique() returns integer
                language sql immutable as $$ select 42 $$;
            """)
        before = _snapshot_public(conn)
        with conn.cursor() as cur:
            cur.execute("update public.restaurants set name = %s where id = %s",
                        ("Fiche modifiée", 42))
        after = _snapshot_public(conn)
        assert before != after
        assert before["relations"]["restaurants"]["row_count"] == 1
        assert before["functions"] != []
