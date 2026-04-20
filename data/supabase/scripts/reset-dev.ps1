# Development reset - includes all dev and test data
Write-Host "Resetting database with development data..."
supabase db reset
Write-Host "Database reset complete with development data!"