# Simple PowerShell script to run RLS check
# Replace these values with your actual Supabase connection details

$DB_HOST = "your-project-ref.supabase.co"  # Replace with your Supabase host
$DB_PORT = "5432"                          # Usually 5432  
$DB_NAME = "postgres"                      # Usually postgres
$DB_USER = "postgres"                      # Usually postgres
$PGPASSWORD = "your-database-password"     # Replace with your actual password

Write-Host "Running RLS check with PowerShell..." -ForegroundColor Green

# Run the PowerShell version of the script
& "scripts/rls-check-focused.ps1" -DB_HOST $DB_HOST -DB_PORT $DB_PORT -DB_NAME $DB_NAME -DB_USER $DB_USER -PGPASSWORD $PGPASSWORD
