# Database Best Practices & Supabase Cleanup Plan

Prioritized hardening and cleanup plan for the AiMindSync Supabase/Postgres database. Overall database health is good; the items below are incremental improvements surfaced by the Supabase Performance and Security advisors.

## Shipped in this change set

Migrations (forward-only, idempotent):

- `supabase/migrations/20261026120000_add_missing_fk_indexes.sql` — adds 8 covering indexes for foreign keys that the Performance Advisor flagged as unindexed (`mentor_requests.course_id`/`module_id`, `scholarship_redemptions.user_id`, `scholarship_seats.created_by`, `social_link_clicks.post_id`, `social_posts.created_by`/`short_link_id`, `social_short_links.created_by`).
- `supabase/migrations/20261026120100_add_rate_limit_primary_keys.sql` — adds surrogate `id bigint GENERATED ALWAYS AS IDENTITY` primary keys to the two rate-limit scratch tables that lack one (`recaptcha_rate_limit`, `lilt_zoom_link_rate_limit`). Identity backfills existing rows, and inserts that omit `id` keep working.

Review-and-run SQL scripts in `docs/sql/` — these **PRINT** statements for an operator to review and run manually against the live DB; **nothing is auto-applied**:

- `docs/sql/rls_wrap_auth_calls.sql` — emits `ALTER POLICY` statements wrapping bare `auth.*()` calls in RLS policies as `(select auth.*())` (fixes the `auth_rls_initplan` advisory); skips calls that are already wrapped.
- `docs/sql/rls_consolidate_permissive_policies.sql` — finds tables with multiple permissive policies for the same role+action and prints a logic-preserving merge template (OR the conditions into one policy).
- `docs/sql/harden_function_search_path.sql` — emits `ALTER FUNCTION ... SET search_path = ''` for `public` functions that do not already pin a search_path (fixes `function_search_path_mutable`).

## Priority order

1. **Confirm the 4 RLS-no-policy tables behave as intended.** Tables with RLS enabled but no policy deny all access by default; verify that is intended for: `growth_metrics_weekly`, `mailerlite_event_ledger`, `marketing_signup_rate_limit`, `module_transcript_chunks`.
2. **Audit privileged SECURITY DEFINER functions:** `grant_admin_user_sd`, `perform_admin_action`, `admin_insert_enrollment`, `deactivate_user`, `claim_orphaned_seat_pools`, `ensure_enrollment_for_entitlement`. A prior review found these already guarded with `has_role(..., 'admin')` and with `EXECUTE` revoked from `anon`/`PUBLIC` — re-confirm on each change.
3. **FK indexes** — *done, this change set.*
4. **RLS policy rewrites:** wrap 68 per-row `auth.*()` calls and consolidate 18 duplicate-permissive policy pairs. Use the `docs/sql/rls_wrap_auth_calls.sql` and `docs/sql/rls_consolidate_permissive_policies.sql` scripts.
5. **Harden function `search_path`** using `docs/sql/harden_function_search_path.sql`.
6. **Rate-limit primary keys** — *done, this change set.*
7. **Classify & drop clutter tables** — classify before dropping (see "Deferred by decision").
8. **Review ~40 unused indexes later** — investigate individually; **do not bulk-drop** (an index can be unused simply because the feature using it is not live yet).

## Dashboard-only settings (operator must change; cannot be a migration)

These live in the Supabase dashboard and have no SQL migration equivalent:

- Switch Auth to **percentage-based connections** (pooler/connection settings).
- Enable **leaked-password protection** (HaveIBeenPwned integration).
- Review **OTP / email-link expiry** windows and available **MFA** options.

## Deferred by decision

- **Move the `vector` extension** from the `public` schema into a dedicated `extensions` schema — deferred to the January baseline; recorded in `security/ignored-findings.json`.
- **Do not bulk-drop the ~40 unused indexes** — review each individually first.
- **Classify clutter tables before dropping** — `function_backups`, `policy_backups`, `uat_discussions`, `smoke_test_runs`, and the empty scaffolding tables need to be classified as *pending-feature* vs *dead* before any drop.

## Operator steps that remain

- **Apply the migrations to the live DB out-of-band.** CI does **not** apply migrations — run `supabase db push` (or the team's usual deploy process).
- **Run the 3 `docs/sql/` scripts in the Supabase SQL editor** and review their printed output before executing any of the generated statements.
- **Make the dashboard settings changes** listed above (percentage-based connections, leaked-password protection, OTP/MFA review).
