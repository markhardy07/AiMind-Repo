# Row Level Security (RLS) Check Setup

This repository now includes automated Row Level Security checks for your Supabase database to ensure all public tables have RLS enabled.

## Files Added

- `.github/workflows/rls-check.yml` - GitHub Actions workflow
- `scripts/check-rls.sh` - Standalone RLS check script

## GitHub Actions Setup

### 1. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** for each of these:

```
SUPABASE_DB_HOST=your-supabase-project-ref.supabase.co
SUPABASE_DB_PORT=5432
SUPABASE_DB_NAME=postgres
SUPABASE_DB_USER=postgres
SUPABASE_DB_PASSWORD=your-supabase-db-password
```

**To find your Supabase connection details:**
1. Go to your Supabase project dashboard
2. Click **Settings** → **Database**
3. Scroll down to **Connection parameters**
4. Use the **Connection string** values

### 2. Database User Requirements

The workflow needs a database user with read access to system tables. You can use:
- **Service Role Key** (recommended for CI)
- A custom database user with these permissions:
  ```sql
  GRANT USAGE ON SCHEMA public TO your_user;
  GRANT SELECT ON pg_class, pg_namespace, pg_policy TO your_user;
  ```

## Local Testing

You can test the RLS check locally using the shell script:

```bash
# Make the script executable
chmod +x scripts/check-rls.sh

# Run with environment variables
PGHOST=your-host.supabase.co \
PGPORT=5432 \
PGDATABASE=postgres \
PGUSER=postgres \
PGPASSWORD=your-password \
./scripts/check-rls.sh
```

## What the Check Does

The workflow will:

1. ✅ **Pass** if all public tables have RLS enabled
2. ❌ **Fail** if any public tables are missing RLS

**Example output when failing:**
```
📊 SUMMARY:
   Total tables: 3
   With RLS: 1
   Without RLS: 2

❌ Tables WITHOUT RLS:
   public.users (RLS DISABLED ✗)
   public.posts (RLS DISABLED ✗)

🚨 SECURITY ALERT: 2 table(s) found without RLS enabled!
```

**Example output when passing:**
```
📊 SUMMARY:
   Total tables: 3
   With RLS: 3
   Without RLS: 0

✅ Tables WITH RLS:
   public.users (RLS ENABLED ✓)
   public.posts (RLS ENABLED ✓)
   public.comments (RLS ENABLED ✓)

✅ All public tables have Row Level Security enabled!
```

## Fixing RLS Issues

If the check fails, enable RLS on the affected tables:

```sql
-- Enable RLS on a table
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;

-- Add a basic policy (example)
CREATE POLICY "Enable read access for authenticated users" 
ON table_name FOR SELECT 
TO authenticated 
USING (true);
```

## Workflow Triggers

The check runs on:
- Push to `main`, `master`, or `develop` branches
- Pull requests targeting `main`, `master`, or `develop` branches

## Security Notes

- The workflow only reads database metadata (non-destructive)
- No sensitive data is accessed or logged
- Connection details are stored securely in GitHub Secrets
- The check uses PostgreSQL system tables: `pg_tables`, `pg_class`, `pg_namespace`, `pg_policy`
