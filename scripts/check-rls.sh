#!/bin/bash

# RLS Security Check Script
# This script checks if all public tables in your Supabase database have Row Level Security enabled
# 
# Usage:
#   ./check-rls.sh
#   Or with custom connection: PGHOST=host PGUSER=user PGPASSWORD=pass ./check-rls.sh
#
# Environment Variables:
#   PGHOST     - Database host (default: localhost)
#   PGPORT     - Database port (default: 5432)
#   PGDATABASE - Database name (default: postgres)
#   PGUSER     - Database user (default: postgres)
#   PGPASSWORD - Database password (required)

set -e

# Set defaults
export PGHOST=${PGHOST:-localhost}
export PGPORT=${PGPORT:-5432}
export PGDATABASE=${PGDATABASE:-postgres}
export PGUSER=${PGUSER:-postgres}

# Check if password is provided
if [ -z "$PGPASSWORD" ]; then
    echo "❌ Error: PGPASSWORD environment variable is required"
    echo "Usage: PGPASSWORD=your_password ./check-rls.sh"
    echo "Or set all connection variables:"
    echo "  PGHOST=your_host PGPORT=5432 PGDATABASE=your_db PGUSER=your_user PGPASSWORD=your_pass ./check-rls.sh"
    exit 1
fi

# Create temporary SQL file
cat > /tmp/rls_check.sql << 'EOF'
-- RLS Security Check Query
-- This query identifies public tables without Row Level Security enabled
WITH public_tables AS (
  SELECT 
    schemaname,
    tablename,
    hasrls,
    CASE 
      WHEN hasrls THEN 'RLS ENABLED ✓'
      ELSE 'RLS DISABLED ✗'
    END as rls_status
  FROM pg_tables 
  WHERE schemaname = 'public'
  ORDER BY tablename
),
summary AS (
  SELECT 
    COUNT(*) as total_tables,
    COUNT(*) FILTER (WHERE hasrls = true) as tables_with_rls,
    COUNT(*) FILTER (WHERE hasrls = false) as tables_without_rls
  FROM public_tables
)
SELECT 
  'SUMMARY:' as info,
  total_tables::text as total,
  tables_with_rls::text as with_rls,
  tables_without_rls::text as without_rls
FROM summary

UNION ALL

SELECT 
  'DETAILS:' as info,
  schemaname || '.' || tablename as table_name,
  rls_status,
  '' as extra
FROM public_tables
WHERE hasrls = false

UNION ALL

SELECT 
  'PASSED:' as info,
  schemaname || '.' || tablename as table_name,
  rls_status,
  '' as extra
FROM public_tables
WHERE hasrls = true;
EOF

# Function to display results
display_results() {
    local results_file="$1"
    
    echo "🔍 Checking Row Level Security on public tables..."
    echo "📡 Connected to: $PGUSER@$PGHOST:$PGPORT/$PGDATABASE"
    echo "=================================================="
    
    # Parse and display results
    local in_summary=false
    local in_details=false
    local in_passed=false
    
    while IFS='|' read -r info total with_rls without_rls; do
        case "$info" in
            "SUMMARY:")
                echo "📊 SUMMARY:"
                echo "   Total tables: $total"
                echo "   With RLS: $with_rls"
                echo "   Without RLS: $without_rls"
                echo ""
                in_summary=true
                ;;
            "DETAILS:")
                if [ "$in_summary" = true ] && [ "$in_details" = false ]; then
                    echo "❌ Tables WITHOUT RLS:"
                    in_details=true
                fi
                if [ "$in_details" = true ]; then
                    echo "   $total ($with_rls)"
                fi
                ;;
            "PASSED:")
                if [ "$in_details" = true ] && [ "$in_passed" = false ]; then
                    echo ""
                    echo "✅ Tables WITH RLS:"
                    in_passed=true
                fi
                if [ "$in_passed" = true ]; then
                    echo "   $total ($with_rls)"
                fi
                ;;
        esac
    done < "$results_file"
}

# Test database connection
echo "🔌 Testing database connection..."
if ! psql -c "SELECT 1;" > /dev/null 2>&1; then
    echo "❌ Error: Cannot connect to database"
    echo "Please check your connection parameters:"
    echo "  Host: $PGHOST"
    echo "  Port: $PGPORT"
    echo "  Database: $PGDATABASE"
    echo "  User: $PGUSER"
    exit 1
fi

echo "✅ Database connection successful!"
echo ""

# Run the RLS check
psql -f /tmp/rls_check.sql -t -A -F'|' > /tmp/rls_results.txt

# Display results
display_results /tmp/rls_results.txt

# Count tables without RLS
tables_without_rls=$(grep "DETAILS:" /tmp/rls_results.txt | wc -l || echo "0")

# Return appropriate exit code
if [ "$tables_without_rls" -gt 0 ]; then
    echo ""
    echo "🚨 SECURITY ALERT: $tables_without_rls table(s) found without RLS enabled!"
    echo "Please enable Row Level Security on all public tables."
    echo ""
    echo "To enable RLS on a table, run:"
    echo "  ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;"
    echo ""
    echo "You can also add RLS policies:"
    echo "  CREATE POLICY policy_name ON table_name FOR ALL TO authenticated USING (true);"
    exit 1
else
    echo ""
    echo "✅ All public tables have Row Level Security enabled!"
    exit 0
fi

# Cleanup
trap 'rm -f /tmp/rls_check.sql /tmp/rls_results.txt' EXIT
