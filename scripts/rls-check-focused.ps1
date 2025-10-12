# PowerShell version of RLS check script
param(
    [Parameter(Mandatory=$true)]
    [string]$DB_HOST,
    
    [Parameter(Mandatory=$false)]
    [string]$DB_PORT = "5432",
    
    [Parameter(Mandatory=$true)]
    [string]$DB_NAME,
    
    [Parameter(Mandatory=$true)]
    [string]$DB_USER,
    
    [Parameter(Mandatory=$true)]
    [string]$PGPASSWORD
)

# Set environment variables
$env:PGPASSWORD = $PGPASSWORD

# SQL query to find public tables without RLS
$SQL = @"
SELECT n.nspname AS table_schema, c.relname AS table_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'  -- ordinary table
  AND c.relrowsecurity = false;
"@

Write-Host "Running RLS check on ${DB_HOST}:${DB_PORT}/${DB_NAME}..." -ForegroundColor Green

try {
    # Run the psql command
    $result = psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c $SQL
    
    if ($result -and $result.Trim() -ne "") {
        Write-Host "ERROR: The following public tables do not have RLS enabled:" -ForegroundColor Red
        Write-Host $result -ForegroundColor Yellow
        Write-Host "Failing the check. Ensure migrations enable RLS and add appropriate policies." -ForegroundColor Red
        exit 1
    } else {
        Write-Host "OK: All public tables have RLS enabled." -ForegroundColor Green
        exit 0
    }
} catch {
    Write-Host "Error running RLS check: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure PostgreSQL client (psql) is installed and accessible." -ForegroundColor Yellow
    exit 1
}
