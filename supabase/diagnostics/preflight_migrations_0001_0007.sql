-- DEKK FOOD — précontrôle non destructif avant les migrations 0001–0007
-- IMPORTANT : ce script est un garde-fou, pas une migration.
-- Il ne crée, ne modifie et ne supprime aucune donnée, table, politique ou privilège.
-- Exécuter d'abord sur une base de test. Sur une base héritée à restaurants.id integer,
-- il doit volontairement échouer avant que les migrations du catalogue soient lancées.

DO $preflight$
DECLARE
  v_id_type text;
  v_missing text[];
  v_legacy_menus bigint := 0;
  v_legacy_reviews bigint := 0;
BEGIN
  IF to_regclass('public.restaurants') IS NULL THEN
    RAISE EXCEPTION
      'PRÉCONTRÔLE BLOQUÉ : public.restaurants est absente. Initialiser d''abord une base de test depuis le schéma de référence attendu.';
  END IF;

  SELECT format_type(a.atttypid, a.atttypmod)
    INTO v_id_type
  FROM pg_attribute a
  WHERE a.attrelid = 'public.restaurants'::regclass
    AND a.attname = 'id'
    AND a.attnum > 0
    AND NOT a.attisdropped;

  IF v_id_type IS DISTINCT FROM 'uuid' THEN
    RAISE EXCEPTION
      'PRÉCONTRÔLE BLOQUÉ : public.restaurants.id est de type %, mais les migrations 0001–0007 attendent uuid. Aucune modification n''a été effectuée. Ne pas lancer les migrations ; suivre docs/PLAN_COMPATIBILITE_SUPABASE.md.',
      coalesce(v_id_type, '(colonne absente)');
  END IF;

  SELECT array_agg(required.column_name ORDER BY required.column_name)
    INTO v_missing
  FROM (VALUES ('name'), ('cuisine_type'), ('neighborhood')) AS required(column_name)
  WHERE NOT EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'restaurants'
      AND c.column_name = required.column_name
  );

  IF coalesce(cardinality(v_missing), 0) > 0 THEN
    RAISE EXCEPTION
      'PRÉCONTRÔLE BLOQUÉ : colonnes héritées attendues absentes de public.restaurants : %. Aucune modification n''a été effectuée.',
      array_to_string(v_missing, ', ');
  END IF;

  IF to_regclass('public.restaurant_menus') IS NOT NULL THEN
    EXECUTE 'SELECT count(*) FROM public.restaurant_menus' INTO v_legacy_menus;
  END IF;

  IF to_regclass('public.restaurant_reviews') IS NOT NULL THEN
    EXECUTE 'SELECT count(*) FROM public.restaurant_reviews' INTO v_legacy_reviews;
  END IF;

  RAISE NOTICE
    'PRÉCONTRÔLE STRUCTUREL PASSÉ : restaurants.id uuid. Tables historiques détectées : restaurant_menus=%, restaurant_reviews=%. Ce résultat ne remplace ni les tests de migrations, ni les contrôles RLS, ni une sauvegarde.',
    v_legacy_menus, v_legacy_reviews;
END
$preflight$;
