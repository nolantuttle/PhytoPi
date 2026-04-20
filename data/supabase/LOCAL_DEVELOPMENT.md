# Local Supabase Development Setup

## Overview

**Best Practice: Always develop locally first, then push to staging/production.**

This workflow ensures:
- ✅ Fast iteration without affecting remote databases
- ✅ Safe experimentation with schema changes
- ✅ No accidental data loss or downtime
- ✅ Testing migrations before deployment
- ✅ Offline development capability

## Prerequisites

The Supabase CLI uses Docker to run a local Supabase instance. You need Docker installed.

### Installing Docker on EndeavourOS (Arch-based)

```bash
# Install Docker and Docker Compose
sudo pacman -S docker docker-compose

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to the docker group (to run without sudo)
sudo usermod -aG docker $USER

# Log out and log back in for group changes to take effect
# Or run: newgrp docker
```

**Verify installation:**
```bash
docker --version
docker-compose --version
```

## Local Development Workflow

### 1. Start Local Supabase Instance

From the `infra/supabase` directory:

```bash
cd /home/danielg/Documents/PhytoPi/infra/supabase
supabase start
```

This will:
- Pull Docker images (first time only, ~2GB download)
- Start all Supabase services (Postgres, API, Auth, Storage, etc.)
- Show you connection details (API URL, anon key, etc.)

**Expected output:**
```
Started supabase local development setup.

         API URL: http://127.0.0.1:54321
     GraphQL URL: http://127.0.0.1:54321/graphql/v1
          DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
      Studio URL: http://127.0.0.1:54323
    Inbucket URL: http://127.0.0.1:54324
      JWT secret: super-secret-jwt-token-with-at-least-32-characters-long
        anon key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
service_role key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### 2. Apply Migrations Locally

Your migrations in `migrations/` are automatically applied when you start Supabase. To reset and reapply:

```bash
# Reset database and apply all migrations + seeds
supabase db reset

# Or just apply new migrations
supabase migration up
```

### 3. Access Supabase Studio

Open http://127.0.0.1:54323 in your browser to:
- View/edit database tables
- Test API endpoints
- Manage authentication
- View logs

### 4. Develop and Test Locally

- Create new migrations: `supabase migration new <name>`
- Test your changes locally
- Verify everything works

### 5. Push to Staging/Production

Once tested locally:

```bash
# Link to your remote project (first time only)
supabase link --project-ref <your-project-ref>

# Push migrations to remote
supabase db push

# Or push to specific environment
supabase db push --db-url <staging-db-url>
```

## Common Commands

```bash
# Start local instance
supabase start

# Stop local instance
supabase stop

# View status
supabase status

# Reset database (applies migrations + seeds)
supabase db reset

# Create new migration
supabase migration new add_new_table

# View local logs
supabase logs

# Generate TypeScript types from local DB
supabase gen types typescript --local > types/database.ts
```

## Configuration

Your `config.toml` is already configured for local development:
- API port: 54321
- Database port: 54322
- Studio port: 54323
- Migrations enabled
- Seeds enabled

## Troubleshooting

### Docker not running
```bash
sudo systemctl status docker
sudo systemctl start docker
```

### Port conflicts
If ports 54321-54329 are in use, modify `config.toml` to use different ports.

### Reset everything
```bash
supabase stop
supabase start
```

### View Docker containers
```bash
docker ps
docker logs supabase_db_<project_id>
```

## Workflow Summary

1. **Local Development** (Recommended)
   ```
   Local → Test → Commit → Push to Git
   ```

2. **Deploy to Staging**
   ```
   Git → CI/CD → Staging DB (via supabase db push)
   ```

3. **Deploy to Production**
   ```
   Staging Verified → Production DB (via supabase db push)
   ```

## Why Local First?

- ⚡ **Speed**: No network latency
- 🔒 **Safety**: Can't break production
- 💰 **Cost**: No API usage charges
- 🧪 **Testing**: Easy to reset and test edge cases
- 📦 **Offline**: Works without internet
- 🔄 **Iteration**: Fast feedback loop

## Next Steps

1. Install Docker (see above)
2. Run `supabase start` from `infra/supabase/` directory
3. Start developing locally!
4. When ready, push to staging with `supabase db push`

