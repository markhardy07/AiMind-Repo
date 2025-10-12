# PowerShell script to run RLS check with Supabase
# Replace the values below with your actual Supabase connection details

$env:DB_HOST = "your-project-ref.supabase.co"  # Replace with your Supabase host
$env:DB_PORT = "5432"                          # Usually 5432
$env:DB_NAME = "postgres"                      # Usually postgres
$env:DB_USER = "postgres"                      # Usually postgres
$env:PGPASSWORD = "your-database-password"     # Replace with your actual password

Write-Host "Setting up environment variables for Supabase connection..." -ForegroundColor Green
Write-Host "DB_HOST: $env:DB_HOST" -ForegroundColor Cyan
Write-Host "DB_PORT: $env:DB_PORT" -ForegroundColor Cyan
Write-Host "DB_NAME: $env:DB_NAME" -ForegroundColor Cyan
Write-Host "DB_USER: $env:DB_USER" -ForegroundColor Cyan
Write-Host "PGPASSWORD: [HIDDEN]" -ForegroundColor Cyan

Write-Host "`nRunning RLS check..." -ForegroundColor Green

# Run the script using bash (if available) or WSL
if (Get-Command bash -ErrorAction SilentlyContinue) {
    bash scripts/rls-check-focused.sh
} elseif (Get-Command wsl -ErrorAction SilentlyContinue) {
    wsl bash scripts/rls-check-focused.sh
} else {
    Write-Host "Error: bash or WSL not found. Please install Git for Windows or WSL to run bash scripts." -ForegroundColor Red
    Write-Host "Alternatively, you can use the GitHub Actions workflow we created earlier." -ForegroundColor Yellow
}
