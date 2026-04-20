# Run supabase inside PhytoPi\infra\supabase directory - supabase start - supabase db reset

# PhytoPi Seed Files

## Overview
This directory contains seed files for populating the PhytoPi database with different types of data.

## Files

- `01_foundation.sql` - Essential system data (users, basic setup)
- `02_dev_data.sql` - Development data (sample devices, sensors)
- `03_test_data.sql` - Test data (sample readings, alerts)
- `04_demo_data.sql` - Demo data (for presentations)

## Usage

### Development Mode (Foundation + Dev + Test)
```bash
supabase db reset
```

### Production Mode (Foundation only)
```bash
# Modify config.toml to only include foundation.sql
supabase db reset
```

### Demo Mode (Foundation + Dev + Demo)
```bash
# Modify config.toml to include foundation + demo files
supabase db reset
```

## Configuration
Edit `config.toml` to control which seed files are loaded:

```toml
[db.seed]
enabled = true
sql_paths = [
    "./seeds/01_foundation.sql",
    "./seeds/02_dev_data.sql",
    "./seeds/03_test_data.sql"
]
```
```

## 3. Update Your Config.toml

Modify your `config.toml` to use the seed directory:

```toml:infra/supabase/config.toml
[db.seed]
# If enabled, seeds the database after migrations during a db reset.
enabled = true
# Specifies an ordered list of seed files to load during db reset.
# Supports glob patterns relative to supabase directory: "./seeds/*.sql"
sql_paths = [
    "./seeds/01_foundation.sql",
    "./seeds/02_dev_data.sql",
    "./seeds/03_test_data.sql"
]
```

## 4. Create Different Configurations

You can create different configurations for different scenarios:

### Development Configuration (Default)
```toml
sql_paths = [
    "./seeds/01_foundation.sql",
    "./seeds/02_dev_data.sql",
    "./seeds/03_test_data.sql"
]
```

### Production Configuration
```toml
sql_paths = [
    "./seeds/01_foundation.sql"
]
```

### Demo Configuration
```toml
sql_paths = [
    "./seeds/01_foundation.sql",
    "./seeds/02_dev_data.sql",
    "./seeds/04_demo_data.sql"
]
```

## 5. Create Helper Scripts

Create a `scripts` directory with helper scripts:

### `infra/supabase/scripts/reset-dev.ps1`
```powershell
# Development reset - includes all dev and test data
Write-Host "Resetting database with development data..."
supabase db reset
Write-Host "Database reset complete with development data!"
```

### `infra/supabase/scripts/reset-prod.ps1`
```powershell
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
```

## 6. Usage Examples

```powershell
# Development (default)
supabase db reset

# Or use the helper script
.\scripts\reset-dev.ps1

# Production (foundation only)
.\scripts\reset-prod.ps1

# Manual control - edit config.toml first, then:
supabase db reset
```

## 7. Commit the Structure

```powershell
git add infra/supabase/seeds/
git add infra/supabase/scripts/
git commit -m "Add flexible seed directory structure

- Organized seeds by purpose (foundation, dev, test, demo)
- Added helper scripts for different reset modes
- Configurable seed loading via config.toml
- Documentation for seed usage"

git push origin your-branch-name
```



This approach gives you complete control over what data gets loaded when, and it's much more maintainable as your project grows!