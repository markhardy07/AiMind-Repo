-- =============================================================================
-- rls_consolidate_permissive_policies.sql  —  REVIEW-AND-RUN diagnostic (prints only)
-- =============================================================================
-- Purpose
--   Supabase's `multiple_permissive_policies` performance advisory flags tables
--   that have MORE THAN ONE permissive RLS policy for the same role and the same
--   action (SELECT / INSERT / UPDATE / DELETE). Every permissive policy for a
--   role+action is evaluated and OR'd together on each row, so N permissive
--   policies mean N expression evaluations per row. Merging them into a single
--   policy whose USING is the OR of the originals preserves the exact same
--   access logic while cutting per-row work.
--
-- What this script does
--   It reads the LIVE policy catalog from `pg_policies`, groups by
--   (schemaname, tablename, cmd, roles, permissive), finds every group with
--   MORE THAN ONE permissive policy, and lists the policy names together with
--   their USING / WITH CHECK expressions. For each such group it also PRINTS a
--   commented TEMPLATE showing how to DROP the duplicates and CREATE one merged
--   policy with the conditions OR'd together.
--
--   It APPLIES NOTHING. The template is intentionally commented out. Copy it into
--   the Supabase SQL editor, fill in / confirm the merged expression, and run it
--   yourself. Any merge MUST be logic-preserving: OR the USING conditions (and,
--   where present, the WITH CHECK conditions) so the combined policy grants
--   exactly the union the separate policies granted.
-- =============================================================================

DO $$
DECLARE
  g         record;
  p         record;
  names     text;
  or_using  text;
  or_check  text;
  first_row boolean;
  n_groups  int := 0;
BEGIN
  RAISE NOTICE '-- Duplicate PERMISSIVE policies — groups to REVIEW and consolidate manually --';

  FOR g IN
    SELECT schemaname, tablename, cmd, roles, permissive, count(*) AS n
    FROM pg_policies
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
      AND permissive = 'PERMISSIVE'
    GROUP BY schemaname, tablename, cmd, roles, permissive
    HAVING count(*) > 1
    ORDER BY schemaname, tablename, cmd, roles
  LOOP
    n_groups := n_groups + 1;
    names := NULL;
    or_using := NULL;
    or_check := NULL;
    first_row := true;

    RAISE NOTICE E'\n-- =====================================================================';
    RAISE NOTICE '-- Table   : %.%', g.schemaname, g.tablename;
    RAISE NOTICE '-- Action  : %   Roles: %   (% permissive policies)', g.cmd, g.roles, g.n;

    FOR p IN
      SELECT policyname, qual, with_check
      FROM pg_policies
      WHERE schemaname = g.schemaname
        AND tablename  = g.tablename
        AND cmd        = g.cmd
        AND roles      = g.roles
        AND permissive = g.permissive
      ORDER BY policyname
    LOOP
      RAISE NOTICE '--   policy %  USING: %  WITH CHECK: %',
        quote_literal(p.policyname), COALESCE(p.qual, '(none)'), COALESCE(p.with_check, '(none)');

      IF first_row THEN
        names := quote_ident(p.policyname);
      ELSE
        names := names || ', ' || quote_ident(p.policyname);
      END IF;

      IF p.qual IS NOT NULL THEN
        or_using := CASE WHEN or_using IS NULL
                         THEN '(' || p.qual || ')'
                         ELSE or_using || ' OR (' || p.qual || ')' END;
      END IF;
      IF p.with_check IS NOT NULL THEN
        or_check := CASE WHEN or_check IS NULL
                         THEN '(' || p.with_check || ')'
                         ELSE or_check || ' OR (' || p.with_check || ')' END;
      END IF;

      first_row := false;
    END LOOP;

    -- Commented merge template (logic-preserving: conditions OR'd together).
    RAISE NOTICE '-- MERGE TEMPLATE (review, then run):';
    RAISE NOTICE '--   DROP POLICY <each-of: %> ON %.%;', names, g.schemaname, g.tablename;
    RAISE NOTICE '--   CREATE POLICY "merged_%_%" ON %.%', lower(g.cmd), g.tablename, g.schemaname, g.tablename;
    RAISE NOTICE '--     AS PERMISSIVE FOR % TO %', g.cmd, g.roles;
    IF or_using IS NOT NULL THEN
      RAISE NOTICE '--     USING (%)', or_using;
    END IF;
    IF or_check IS NOT NULL THEN
      RAISE NOTICE '--     WITH CHECK (%)', or_check;
    END IF;
    RAISE NOTICE '--   ;';
  END LOOP;

  IF n_groups = 0 THEN
    RAISE NOTICE 'No role+action has multiple permissive policies. Nothing to consolidate.';
  ELSE
    RAISE NOTICE E'\n-- % duplicate-permissive group(s) above. Review each merge before running. --', n_groups;
  END IF;
END;
$$;
