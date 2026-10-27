-- =============================================================================
-- harden_function_search_path.sql  —  REVIEW-AND-RUN diagnostic (prints only)
-- =============================================================================
-- Purpose
--   Supabase's `function_search_path_mutable` security advisory flags functions
--   that do NOT pin their `search_path`. A function with a mutable search_path can
--   be tricked into resolving object names against an attacker-controlled schema
--   (search-path injection), which is especially dangerous for SECURITY DEFINER
--   functions. Pinning the search_path removes that ambiguity.
--
-- What this script does
--   It reads the LIVE catalog (`pg_proc` joined to `pg_namespace`), finds every
--   function in the `public` schema whose `proconfig` does NOT already contain a
--   `search_path` setting, and PRINTS the exact
--       ALTER FUNCTION <schema>.<name>(<args>) SET search_path = '';
--   statement needed to harden it. An empty search_path is the recommended
--   hardened default (force fully-qualified names inside the function body); if a
--   particular function genuinely needs it, use `SET search_path = public, pg_temp`
--   instead — review each case.
--
--   It APPLIES NOTHING. Functions that already pin a search_path in `proconfig`
--   are skipped, so re-running produces no statements once everything is hardened.
--   Copy the printed statements into the Supabase SQL editor, review, and run them.
-- =============================================================================

DO $$
DECLARE
  r        record;
  n_found  int := 0;
BEGIN
  RAISE NOTICE '-- Functions missing a pinned search_path — statements to REVIEW and run manually --';

  FOR r IN
    SELECT n.nspname                             AS schema_name,
           p.proname                             AS func_name,
           pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind IN ('f', 'p')   -- normal functions and procedures
      AND NOT EXISTS (
        SELECT 1
        FROM unnest(COALESCE(p.proconfig, ARRAY[]::text[])) AS cfg
        WHERE cfg ILIKE 'search_path=%'
      )
    ORDER BY n.nspname, p.proname, args
  LOOP
    n_found := n_found + 1;
    RAISE NOTICE 'ALTER FUNCTION %.%(%) SET search_path = '''';',
      quote_ident(r.schema_name), quote_ident(r.func_name), r.args;
  END LOOP;

  IF n_found = 0 THEN
    RAISE NOTICE 'All public functions already pin search_path. Nothing to do.';
  ELSE
    RAISE NOTICE '-- % function(s) above need hardening. Review, then run in the SQL editor. --', n_found;
  END IF;
END;
$$;
