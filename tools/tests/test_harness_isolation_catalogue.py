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
    result: dict[str, Any] = {
        "relations": {}, "functions": [], "types": [], "policies": [], "triggers": [], "acl": [], "sequences": [], "sequence_ownership": [], "catalogue_fks_to_public": []
    }
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
                select c.relrowsecurity, c.relforcerowsecurity
                from pg_class c
                join pg_namespace n on n.oid = c.relnamespace
                where n.nspname = 'public' and c.relname = %s
            """, (name,))
            rls_flags = cur.fetchone()
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
            view_definition = None
            if kind in ("v", "m"):
                cur.execute("""
                    select pg_get_viewdef(c.oid, true)
                    from pg_class c join pg_namespace n on n.oid = c.relnamespace
                    where n.nspname = 'public' and c.relname = %s
                """, (name,))
                view_definition = cur.fetchone()[0]
            if kind in ("r", "p", "m"):
                quoted = '"' + name.replace('"', '""') + '"'
                cur.execute(f"select to_jsonb(t) from public.{quoted} as t")
                rows = [json.dumps(row[0], sort_keys=True, ensure_ascii=False, default=str)
                        for row in cur.fetchall()]
                rows.sort()
            payload = {
                "kind": kind,
                "view_definition": view_definition,
                "rls": rls_flags,
                "columns": columns,
                "constraints": constraints,
                "indexes": indexes,
                "row_count": len(rows) if kind in ("r", "p", "m") else None,
                "rows_sha256": hashlib.sha256("\n".join(rows).encode()).hexdigest()
                    if kind in ("r", "p", "m") else None,
            }
            result["relations"][name] = json.loads(json.dumps(payload, default=str))
        cur.execute("""
            select p.proname, pg_get_function_identity_arguments(p.oid),
                   pg_get_functiondef(p.oid)
            from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' order by p.proname, 2
        """)
        result["functions"] = cur.fetchall()
        cur.execute("""
            select t.typname, t.typtype, format_type(t.oid, null), t.typnotnull,
                   t.typdefault,
                   coalesce((select string_agg(e.enumlabel, ',' order by e.enumsortorder)
                             from pg_enum e where e.enumtypid = t.oid), '') as enum_labels,
                   coalesce((select string_agg(pg_get_constraintdef(c.oid, true), ' | ' order by c.conname)
                             from pg_constraint c where c.contypid = t.oid), '') as domain_constraints,
                   coalesce((select string_agg(
                               format('%s:%s:%s', a.attname, format_type(a.atttypid, a.atttypmod), a.attnotnull),
                               ',' order by a.attnum)
                             from pg_class rc
                             join pg_attribute a on a.attrelid = rc.oid
                             where rc.reltype = t.oid and a.attnum > 0 and not a.attisdropped),
                            '') as composite_attributes
            from pg_type t join pg_namespace n on n.oid = t.typnamespace
            where n.nspname = 'public' and t.typtype in ('c', 'd', 'e', 'r', 'm')
            order by t.typname
        """)
        result["types"] = cur.fetchall()
        cur.execute("""
            select schemaname, tablename, policyname, permissive, roles,
                   cmd, qual, with_check
            from pg_policies
            where schemaname = 'public'
            order by tablename, policyname
        """)
        result["policies"] = cur.fetchall()
        cur.execute("""
            select n.nspname, c.relname, t.tgname, pg_get_triggerdef(t.oid, true)
            from pg_trigger t
            join pg_class c on c.oid = t.tgrelid
            join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and not t.tgisinternal
            order by c.relname, t.tgname
        """)
        result["triggers"] = cur.fetchall()
        cur.execute("""
            select 'relation', n.nspname, c.relname, c.relkind,
                   coalesce(c.relacl::text, '')
            from pg_class c
            join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public'
            union all
            select 'schema', n.nspname, '', '', coalesce(n.nspacl::text, '')
            from pg_namespace n where n.nspname = 'public'
            union all
            select 'function', n.nspname,
                   p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
                   '', coalesce(p.proacl::text, '')
            from pg_proc p
            join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public'
            order by 1, 2, 3, 4
        """)
        result["acl"] = cur.fetchall()
        cur.execute("""
            select schemaname, sequencename, data_type, start_value, min_value,
                   max_value, increment_by, cycle, cache_size, last_value
            from pg_sequences
            where schemaname = 'public'
            order by sequencename
        """)
        result["sequences"] = cur.fetchall()
        cur.execute("""
            select seq_ns.nspname, seq.relname,
                   tbl_ns.nspname, tbl.relname, attr.attname,
                   dep.deptype
            from pg_class seq
            join pg_namespace seq_ns on seq_ns.oid = seq.relnamespace
            join pg_depend dep on dep.classid = 'pg_class'::regclass
                             and dep.objid = seq.oid
                             and dep.refclassid = 'pg_class'::regclass
                             and dep.deptype in ('a', 'i')
            join pg_class tbl on tbl.oid = dep.refobjid
            join pg_namespace tbl_ns on tbl_ns.oid = tbl.relnamespace
            join pg_attribute attr on attr.attrelid = tbl.oid
                                  and attr.attnum = dep.refobjsubid
            where seq_ns.nspname = 'public' and seq.relkind = 'S'
            order by seq.relname
        """)
        result["sequence_ownership"] = cur.fetchall()
        cur.execute("""
            select sn.nspname, sc.relname, tn.nspname, tc.relname,
                   con.conname, pg_get_constraintdef(con.oid, true)
            from pg_constraint con
            join pg_class sc on sc.oid = con.conrelid
            join pg_namespace sn on sn.oid = sc.relnamespace
            join pg_class tc on tc.oid = con.confrelid
            join pg_namespace tn on tn.oid = tc.relnamespace
            where con.contype = 'f'
              and sn.nspname = 'catalogue'
              and tn.nspname = 'public'
            order by sc.relname, con.conname
        """)
        result["catalogue_fks_to_public"] = cur.fetchall()
    return json.loads(json.dumps(result, sort_keys=True, default=str))




MIGRATIONS_HISTORIQUES_INTERDITES = {
    "0001_referentiel_et_catalogue.sql",
    "0002_menus_images_services.sql",
    "0003_securite_vues_admin.sql",
    "0004_publication_validation_provenance.sql",
    "0005_cloisonnement_public.sql",
    "0006_acces_admin_restaurateur.sql",
    "0007_securite_vues_et_fonctions.sql",
}


def migrations_historiques_interdites(noms: list[str]) -> list[str]:
    """Repère les migrations historiques qui ne doivent pas servir de série catalogue."""
    return sorted(set(noms) & MIGRATIONS_HISTORIQUES_INTERDITES)



def _verifier_fixture_historique(conn: Any) -> list[str]:
    """Refuse une fixture trop vide pour représenter le contrat historique minimal."""
    erreurs: list[str] = []
    tables = {
        "restaurants": {"id": "integer"},
        "restaurant_menus": {"id": "integer", "restaurant_id": "integer"},
        "restaurant_reviews": {"id": "integer", "restaurant_id": "integer"},
    }
    with conn.cursor() as cur:
        for table, colonnes_attendues in tables.items():
            cur.execute("""
                select a.attname, format_type(a.atttypid, a.atttypmod)
                from pg_attribute a
                join pg_class c on c.oid = a.attrelid
                join pg_namespace n on n.oid = c.relnamespace
                where n.nspname = 'public' and c.relname = %s
                  and a.attnum > 0 and not a.attisdropped
            """, (table,))
            colonnes = dict(cur.fetchall())
            if not colonnes:
                erreurs.append(f"public.{table} absent ou sans colonnes")
                continue
            for colonne, type_attendu in colonnes_attendues.items():
                if colonnes.get(colonne) != type_attendu:
                    erreurs.append(
                        f"public.{table}.{colonne}: type attendu {type_attendu}, "
                        f"trouvé {colonnes.get(colonne, 'absent')}"
                    )
            cur.execute(f'SELECT count(*) FROM public."{table}"')
            if cur.fetchone()[0] < 1:
                erreurs.append(f"public.{table} ne contient aucune ligne témoin")

        # Les deux tables enfants doivent réellement référencer restaurants(id).
        # Vérifier seulement le nom et le type des colonnes laisserait passer
        # une fixture incomplète, donc incapable de tester l'intégrité historique.
        for table in ("restaurant_menus", "restaurant_reviews"):
            cur.execute("""
                select count(*)
                from pg_constraint con
                join pg_class child on child.oid = con.conrelid
                join pg_namespace child_ns on child_ns.oid = child.relnamespace
                join pg_class parent on parent.oid = con.confrelid
                join pg_namespace parent_ns on parent_ns.oid = parent.relnamespace
                join pg_attribute child_attr
                  on child_attr.attrelid = child.oid
                 and child_attr.attname = 'restaurant_id'
                 and not child_attr.attisdropped
                join pg_attribute parent_attr
                  on parent_attr.attrelid = parent.oid
                 and parent_attr.attname = 'id'
                 and not parent_attr.attisdropped
                where con.contype = 'f'
                  and child_ns.nspname = 'public' and child.relname = %s
                  and parent_ns.nspname = 'public' and parent.relname = 'restaurants'
                  and con.conkey = ARRAY[child_attr.attnum]::smallint[]
                  and con.confkey = ARRAY[parent_attr.attnum]::smallint[]
            """, (table,))
            if cur.fetchone()[0] < 1:
                erreurs.append(
                    f"public.{table}.restaurant_id ne référence pas public.restaurants(id)"
                )
    return erreurs

def _relations_catalogue(conn: Any) -> set[tuple[str, str]]:
    """Liste les tables/vues du schéma catalogue pour éviter une fausse preuve à vide."""
    with conn.cursor() as cur:
        cur.execute("""
            select c.relname, c.relkind
            from pg_class c
            join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'catalogue'
              and c.relkind in ('r', 'p', 'v', 'm', 'f')
            order by c.relname, c.relkind
        """)
        return set(cur.fetchall())

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
    interdites = migrations_historiques_interdites([migration.name for migration in migrations])
    if interdites:
        parser.error(
            "Migrations historiques interdites dans le harness catalogue : "
            + ", ".join(interdites)
            + ". Créer une série autonome de migrations catalogue ; ne pas transformer/appliquer les historiques."
        )
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
        erreurs_fixture = _verifier_fixture_historique(conn)
        if erreurs_fixture:
            parser.error(
                "Fixture historique insuffisante pour le contrat minimal : "
                + "; ".join(erreurs_fixture)
            )
        before = _snapshot_public(conn)
        relations_catalogue_avant = _relations_catalogue(conn)
        for migration in migrations:
            print(f"Application jetable : {migration.name}")
            with conn.cursor() as cur:
                cur.execute(migration.read_text(encoding="utf-8"))
        after = _snapshot_public(conn)
        relations_catalogue_apres = _relations_catalogue(conn)
        nouvelles_relations_catalogue = relations_catalogue_apres - relations_catalogue_avant
        if not nouvelles_relations_catalogue:
            print("ÉCHEC : aucune nouvelle table/vue catalogue détectée ; une migration vide ne constitue pas une preuve.")
            return 1
        if after["catalogue_fks_to_public"]:
            print("ÉCHEC : clés étrangères du catalogue vers public interdites :",
                  after["catalogue_fks_to_public"])
            return 1
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


def test_snapshot_detecte_une_modification_de_type_composite():
    try:
        import pgserver  # type: ignore
        import psycopg  # type: ignore
    except ImportError as exc:
        raise AssertionError(f"Les tests du harness exigent pgserver et psycopg : {exc}") from exc
    server = pgserver.get_server(tempfile.mkdtemp(prefix="dekk-harness-composite-"))
    with psycopg.connect(server.get_uri(), autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                create type public.synthetic_address as (
                    street text,
                    postal_code integer
                );
            """)
        before = _snapshot_public(conn)
        before_type = next(t for t in before["types"] if t[0] == "synthetic_address")
        assert "street:text" in before_type[7]
        with conn.cursor() as cur:
            cur.execute("alter type public.synthetic_address add attribute country text")
        after = _snapshot_public(conn)
        after_type = next(t for t in after["types"] if t[0] == "synthetic_address")
        assert before_type != after_type
        assert "country:text" in after_type[7]


def test_snapshot_detecte_une_modification_de_vue_et_type_personnalise():
    try:
        import pgserver  # type: ignore
        import psycopg  # type: ignore
    except ImportError as exc:
        raise AssertionError(f"Les tests du harness exigent pgserver et psycopg : {exc}") from exc
    server = pgserver.get_server(tempfile.mkdtemp(prefix="dekk-harness-types-"))
    with psycopg.connect(server.get_uri(), autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                create table public.restaurants (id integer primary key, name text not null);
                insert into public.restaurants values (42, 'Fiche témoin');
                create view public.restaurant_summary as
                    select id, name from public.restaurants where id > 0;
                create type public.synthetic_status as enum ('draft', 'published');
            """)
        before = _snapshot_public(conn)
        assert before["relations"]["restaurant_summary"]["view_definition"]
        assert any(t[0] == "synthetic_status" and "draft,published" in t[5]
                   for t in before["types"])
        with conn.cursor() as cur:
            cur.execute("""
                create or replace view public.restaurant_summary as
                    select id, name from public.restaurants where id >= 0;
            """)
            cur.execute("alter type public.synthetic_status add value 'archived'")
        after = _snapshot_public(conn)
        assert before["relations"]["restaurant_summary"]["view_definition"] != after["relations"]["restaurant_summary"]["view_definition"]
        before_status = next(t for t in before["types"] if t[0] == "synthetic_status")
        after_status = next(t for t in after["types"] if t[0] == "synthetic_status")
        assert before_status != after_status


def test_harness_refuse_un_schema_catalogue_sans_relation():
    try:
        import pgserver  # type: ignore
        import psycopg  # type: ignore
    except ImportError as exc:
        raise AssertionError(f"Les tests du harness exigent pgserver et psycopg : {exc}") from exc
    server = pgserver.get_server(tempfile.mkdtemp(prefix="dekk-harness-catalogue-vide-"))
    with psycopg.connect(server.get_uri(), autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute("create schema catalogue")
        assert _relations_catalogue(conn) == set()
        with conn.cursor() as cur:
            cur.execute("create table catalogue.etablissements (id uuid primary key)")
        assert _relations_catalogue(conn) == {("etablissements", "r")}


def test_harness_refuse_les_migrations_historiques():
    assert migrations_historiques_interdites([
        "0001_referentiel_et_catalogue.sql",
        "0004_publication_validation_provenance.sql",
        "catalogue_0001_schema.sql",
    ]) == [
        "0001_referentiel_et_catalogue.sql",
        "0004_publication_validation_provenance.sql",
    ]


def test_harness_accepte_une_serie_dediee_catalogue():
    assert migrations_historiques_interdites([
        "catalogue_0001_schema.sql",
        "catalogue_0002_policies.sql",
    ]) == []


def test_fixture_historique_minimale_est_verifiee():
    try:
        import pgserver  # type: ignore
        import psycopg  # type: ignore
    except ImportError as exc:
        raise AssertionError(f"Les tests du harness exigent pgserver et psycopg : {exc}") from exc
    server = pgserver.get_server(tempfile.mkdtemp(prefix="dekk-harness-fixture-check-"))
    with psycopg.connect(server.get_uri(), autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                create table public.restaurants (id integer primary key, name text not null);
                create table public.restaurant_menus (
                    id integer primary key, restaurant_id integer not null
                        references public.restaurants(id)
                );
                create table public.restaurant_reviews (
                    id integer primary key, restaurant_id integer not null
                        references public.restaurants(id)
                );
                insert into public.restaurants values (42, 'Témoin');
                insert into public.restaurant_menus values (7, 42);
                insert into public.restaurant_reviews values (9, 42);
            """)
        assert _verifier_fixture_historique(conn) == []
        for table in ("restaurant_menus", "restaurant_reviews"):
            constraint = f"{table}_restaurant_id_fkey"
            with conn.cursor() as cur:
                cur.execute(f'ALTER TABLE public."{table}" DROP CONSTRAINT "{constraint}"')
            assert (
                f"public.{table}.restaurant_id ne référence pas public.restaurants(id)"
                in _verifier_fixture_historique(conn)
            )
            with conn.cursor() as cur:
                cur.execute(
                    f'ALTER TABLE public."{table}" ADD CONSTRAINT "{constraint}" '
                    "FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id)"
                )
        with conn.cursor() as cur:
            cur.execute("delete from public.restaurant_menus")
        assert "public.restaurant_menus ne contient aucune ligne témoin" in (
            _verifier_fixture_historique(conn)
        )

def test_snapshot_detecte_la_perte_de_propriete_d_une_sequence():
    try:
        import pgserver  # type: ignore
        import psycopg  # type: ignore
    except ImportError as exc:
        raise AssertionError(f"Les tests du harness exigent pgserver et psycopg : {exc}") from exc
    server = pgserver.get_server(tempfile.mkdtemp(prefix="dekk-harness-sequence-owner-"))
    with psycopg.connect(server.get_uri(), autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                create table public.sequence_owner_probe (id integer);
                create sequence public.sequence_owner_probe_seq;
                alter sequence public.sequence_owner_probe_seq
                    owned by public.sequence_owner_probe.id;
            """)
        before = _snapshot_public(conn)
        assert ["public", "sequence_owner_probe_seq", "public",
                "sequence_owner_probe", "id", "a"] in before["sequence_ownership"]
        with conn.cursor() as cur:
            cur.execute("alter sequence public.sequence_owner_probe_seq owned by none")
        after = _snapshot_public(conn)
        assert before["sequence_ownership"] != after["sequence_ownership"]


def test_snapshot_detecte_les_changements_de_policies_triggers_et_acl():
    try:
        import pgserver  # type: ignore
        import psycopg  # type: ignore
    except ImportError as exc:
        raise AssertionError(f"Les tests du harness exigent pgserver et psycopg : {exc}") from exc
    server = pgserver.get_server(tempfile.mkdtemp(prefix="dekk-harness-security-snapshot-"))
    with psycopg.connect(server.get_uri(), autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                create role synthetic_reader;
                create table public.security_probe (id integer primary key, visible boolean not null);
                insert into public.security_probe values (1, true);
                create function public.security_probe_trigger_fn()
                returns trigger language plpgsql as $$
                begin
                    new.visible := coalesce(new.visible, false);
                    return new;
                end;
                $$;
                create trigger security_probe_trigger
                    before insert on public.security_probe
                    for each row execute function public.security_probe_trigger_fn();
                alter table public.security_probe enable row level security;
                create policy security_probe_policy on public.security_probe
                    for select to synthetic_reader using (visible);
                grant select on public.security_probe to synthetic_reader;
            """)
        before = _snapshot_public(conn)
        assert any(policy[2] == "security_probe_policy" for policy in before["policies"])
        assert any(trigger[2] == "security_probe_trigger" for trigger in before["triggers"])
        assert any(entry[2] == "security_probe" and "synthetic_reader" in str(entry[4])
                   for entry in before["acl"])

        with conn.cursor() as cur:
            cur.execute("drop policy security_probe_policy on public.security_probe")
        after_policy = _snapshot_public(conn)
        assert before["policies"] != after_policy["policies"]

        with conn.cursor() as cur:
            cur.execute("""
                create policy security_probe_policy on public.security_probe
                    for select to synthetic_reader using (id > 0)
            """)
        before_trigger = _snapshot_public(conn)
        with conn.cursor() as cur:
            cur.execute("drop trigger security_probe_trigger on public.security_probe")
        after_trigger = _snapshot_public(conn)
        assert before_trigger["triggers"] != after_trigger["triggers"]

        before_acl = _snapshot_public(conn)
        with conn.cursor() as cur:
            cur.execute("revoke select on public.security_probe from synthetic_reader")
        after_acl = _snapshot_public(conn)
        assert before_acl["acl"] != after_acl["acl"]
