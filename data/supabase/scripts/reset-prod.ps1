# Production reset - foundation only
Write-Host "Resetting database with production data..."
# Temporarily modify config.toml to only include foundation.sql
$configContent = Get-Content "config.toml" -Raw
$configContent = $configContent -replace 'sql_paths = \[.*?\]', 'sql_paths = ["./seeds/01_foundation.sql"]'
$configContent | Set-Content "config.toml"

supabase db reset

# Restore original config
$configContent = $configContent -replace 'sql_paths = \["./seeds/01_foundation.sql"\]', 'sql_paths = ["./seeds/01_foundation.sql", "./seeds/02_dev_data.sql", "./seeds/03_test_data.sql"]'
$configContent | Set-Content "config.toml"

Write-Host "Database reset complete with production data!"