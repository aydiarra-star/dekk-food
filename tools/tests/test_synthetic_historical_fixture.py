"""Valide uniquement le chargement de la fixture synthétique, jamais la production."""
from __future__ import annotations

import tempfile
from pathlib import Path

import pgserver
import psycopg
import pytest


FIXTURE = Path(__file__).parent / "fixtures" / "synthetic_historical_public.sql"


def test_fixture_historique_synthetique_est_chargeable_et_representee():
    assert FIXTURE.is_file(), "La fixture synthétique doit être versionnée."
    server = pgserver.get_server(tempfile.mkdtemp(prefix="dekk-synthetic-fixture-"))

    with psycopg.connect(server.get_uri(), autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(FIXTURE.read_text(encoding="utf-8"))

            cur.execute("""
                SELECT count(*) FROM information_schema.tables
                WHERE table_schema = 'public'
                  AND table_name IN ('restaurants', 'restaurant_menus', 'restaurant_reviews')
            """)
            assert cur.fetchone()[0] == 3

            cur.execute("SELECT id, name FROM public.restaurants")
            assert cur.fetchone() == (42, "Fixture synthétique — restaurant témoin")

            cur.execute("SELECT restaurant_id, name FROM public.restaurant_menus")
            assert cur.fetchone() == (42, "Menu synthétique")

            cur.execute("SELECT restaurant_id, rating FROM public.restaurant_reviews")
            assert cur.fetchone() == (42, 5)

            cur.execute("""
                SELECT data_type FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'restaurants'
                  AND column_name = 'id'
            """)
            assert cur.fetchone()[0] == "integer"

            cur.execute("""
                SELECT count(*) FROM pg_policies
                WHERE schemaname = 'public'
                  AND tablename = 'restaurant_reviews'
                  AND policyname = 'synthetic_review_read_policy'
            """)
            assert cur.fetchone()[0] == 1

            cur.execute("""
                SELECT c.relrowsecurity
                FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = 'public' AND c.relname = 'restaurant_reviews'
            """)
            assert cur.fetchone()[0] is True

            cur.execute("""
                SELECT count(*) FROM pg_trigger t
                JOIN pg_class c ON c.oid = t.tgrelid
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = 'public'
                  AND c.relname = 'restaurant_reviews'
                  AND t.tgname = 'synthetic_review_guard_trigger'
                  AND NOT t.tgisinternal
            """)
            assert cur.fetchone()[0] == 1

            cur.execute("SELECT public.synthetic_history_marker()")
            assert cur.fetchone()[0] == 42

            # Le trigger refuse une note invalide à l'insertion comme à la mise à jour.
            with pytest.raises(psycopg.errors.RaiseException):
                cur.execute("""
                    INSERT INTO public.restaurant_reviews (restaurant_id, rating, body)
                    VALUES (42, 6, 'Cette ligne doit être refusée')
                """)

            with pytest.raises(psycopg.errors.RaiseException):
                cur.execute("UPDATE public.restaurant_reviews SET rating = 0 WHERE id = 9")

            # Les relations historiques synthétiques conservent leurs contraintes d'intégrité.
            with pytest.raises(psycopg.errors.ForeignKeyViolation):
                cur.execute("""
                    INSERT INTO public.restaurant_menus (restaurant_id, name)
                    VALUES (999, 'Menu orphelin interdit')
                """)

            with pytest.raises(psycopg.errors.UniqueViolation):
                cur.execute("""
                    INSERT INTO public.restaurant_menus (restaurant_id, name)
                    VALUES (42, 'Menu synthétique')
                """)

            # La séquence par défaut reste fonctionnelle après l'insertion d'un ID explicite.
            cur.execute("""
                INSERT INTO public.restaurants (name)
                VALUES ('Restaurant séquence synthétique')
                RETURNING id
            """)
            assert cur.fetchone()[0] == 1000
