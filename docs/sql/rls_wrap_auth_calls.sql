-- =============================================================================
-- rls_wrap_auth_calls.sql  —  REVIEW-AND-RUN diagnostic (prints only)
-- =============================================================================
-- Purpose
--   Supabase's `auth_rls_initplan` performance advisory flags RLS policies whose
--   USING / WITH CHECK expressions call `auth.uid()`, `auth.jwt()`, `auth.role()`
--   or `auth.email()` directly. A bare call is re-evaluated once PER ROW; wrapping
--   it as `(select auth.uid())` lets the planner evaluate it ONCE per statement
--   (an InitPlan), which is dramatically cheaper on large scans.
--
-- What this script does
--   It reads the LIVE policy definitions from `pg_policies`, finds every bare
--   (unwrapped) `auth.<fn>()` call, and PRINTS the exact
--       ALTER POLICY <name> ON <schema>.<table> USING (...) [WITH CHECK (...)];
--   statement that wraps each bare call in `(select auth.<fn>())`.
--
--   It APPLIES NOTHING. Copy the printed statements into the Supabase SQL editor,
--   review them against the live policies, and run them yourself.
--
-- Idempotency / no double-wrapping
--   Postgres deparses an already-wrapped call as `( SELECT auth.uid() AS uid )`
--   (uppercase SELECT, with an `AS <alias>`). This script detects calls that are
--   already inside a `select auth.*` sub-expression (case-insensitive) and SKIPS
--   them, so re-running it produces no statements once every policy is fixed.
--
-- Note: it creates one SESSION-LOCAL temp helper (pg_temp.wrap_auth_calls) that
-- exists only for this connection and is dropped automatically at disconnect.
-- Nothing in the real schema is modified.
-- =============================================================================

-- Session-local helper: wrap bare auth.<fn>() calls, leaving already-wrapped ones.
CREATE OR REPLACE FUNCTION pg_temp.wrap_auth_calls(expr text)
RETURNS text
LANGUAGE plpgsql
AS $fn$
DECLARE
  out_expr text := expr;
BEGIN
  IF out_expr IS NULL THEN
    RETURN NULL;
  END IF;

  -- 1. Protect calls that are ALREADY wrapped: `( SELECT auth.uid() AS uid )`
  --    and the alias-less form `( select auth.uid() )`. Replace with a sentinel
  --    so the bare-wrap pass below cannot touch them.
  out_expr := regexp_replace(
    out_expr,
    '\(\s*select\s+(auth\.[a-z_]+\(\))\s+as\s+[a-z_]+\s*\)',
    E'\x01\\1\x02', 'gi');
  out_expr := regexp_replace(
    out_expr,
    '\(\s*select\s+(auth\.[a-z_]+\(\))\s*\)',
    E'\x01\\1\x02', 'gi');

  -- 2. Wrap every remaining (bare) auth.<fn>() call.
  out_expr := regexp_replace(
    out_expr,
    '(auth\.(?:uid|jwt|role|email)\(\))',
    '(select \1)', 'gi');

  -- 3. Restore the protected (already-wrapped) calls.
  out_expr := regexp_replace(
    out_expr,
    E'\x01(auth\\.[a-z_]+\\(\\))\x02',
    '(select \1)', 'g');

  RETURN out_expr;
END;
$fn$;

DO $$
DECLARE
  r              record;
  new_qual       text;
  new_check      text;
  stmt           text;
  n_found        int := 0;
BEGIN
  RAISE NOTICE '-- RLS auth.*() wrapping — statements to REVIEW and run manually --';
  FOR r IN
    SELECT schemaname, tablename, policyname, qual, with_check
    FROM pg_policies
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
      AND (
        -- only consider policies that reference auth.* at all
        COALESCE(qual, '')       ~* 'auth\.(uid|jwt|role|email)\('
        OR COALESCE(with_check,'') ~* 'auth\.(uid|jwt|role|email)\('
      )
    ORDER BY schemaname, tablename, policyname
  LOOP
    new_qual  := pg_temp.wrap_auth_calls(r.qual);
    new_check := pg_temp.wrap_auth_calls(r.with_check);

    -- Emit only when wrapping actually changed something (i.e. a bare call existed).
    IF new_qual IS DISTINCT FROM r.qual
       OR new_check IS DISTINCT FROM r.with_check THEN
      n_found := n_found + 1;
      stmt := format('ALTER POLICY %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
      IF r.qual IS NOT NULL THEN
        stmt := stmt || format(E'\n  USING (%s)', new_qual);
      END IF;
      IF r.with_check IS NOT NULL THEN
        stmt := stmt || format(E'\n  WITH CHECK (%s)', new_check);
      END IF;
      stmt := stmt || ';';
      RAISE NOTICE E'\n%', stmt;
    END IF;
  END LOOP;

  IF n_found = 0 THEN
    RAISE NOTICE 'No policies with unwrapped auth.*() calls found. Nothing to do.';
  ELSE
    RAISE NOTICE '-- % policy(ies) above need wrapping. Review, then run in the SQL editor. --', n_found;
  END IF;
END;
$$;
