# PhytoPi Dashboard Quick Start

Quick start guide for local development and deployment.

## Local Development

### 1. Start Supabase

```bash
cd infra/supabase
supabase start
```

### 2. Run Dashboard

```bash
cd dashboard
./scripts/run_local.sh
```

The app will open at http://localhost:3000

## Production Deployment to Vercel

### Option 1: Using Vercel CLI (Recommended)

1. **Install Vercel CLI:**
   ```bash
   npm install -g vercel
   ```

2. **Login:**
   ```bash
   vercel login
   ```

3. **Set environment variables:**
   ```bash
   cd dashboard
   vercel env add SUPABASE_URL production
   # Enter: https://your-project.supabase.co
   
   vercel env add SUPABASE_ANON_KEY production
   # Enter: your-production-anon-key
   ```

4. **Deploy:**
   ```bash
   vercel --prod
   ```

### Option 2: Using Vercel Dashboard

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Click "Add New Project"
3. Import your Git repository
4. Configure:
   - **Root Directory:** `dashboard`
   - **Build Command:** `chmod +x scripts/build.sh && bash scripts/build.sh`
   - **Output Directory:** `build/web`
   - **Framework Preset:** Other
5. Add environment variables:
   - `SUPABASE_URL`: Your production Supabase URL
   - `SUPABASE_ANON_KEY`: Your production Supabase anon key
6. Click "Deploy"

### Option 3: Using GitHub Actions (Automated)

1. Add secrets to GitHub repository:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `VERCEL_TOKEN`
   - `VERCEL_ORG_ID`
   - `VERCEL_PROJECT_ID`

2. Push to `main` branch - deployment happens automatically!

## Getting Supabase Keys

### Local Development
```bash
cd infra/supabase
supabase status
# Look for "anon key" in output
```

### Production
1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Go to Settings > API
4. Copy:
   - **Project URL** → `SUPABASE_URL`
   - **anon public** key → `SUPABASE_ANON_KEY`

## Push Database Migrations

```bash
cd infra/supabase
supabase link --project-ref your-project-ref
supabase db push
```

## Configure Auth Redirect URLs

In Supabase Dashboard > Authentication > URL Configuration:
- **Site URL:** `https://your-vercel-app.vercel.app`
- **Redirect URLs:** Add your Vercel domain with `/**` wildcard

## Troubleshooting

### Build fails on Vercel
- Check that environment variables are set
- Verify Flutter installation (build script installs it automatically)
- Check build logs for specific errors

### Can't connect to Supabase
- Verify `SUPABASE_URL` is correct (should start with `https://`)
- Check CORS settings in Supabase dashboard
- Verify redirect URLs are configured

### Authentication not working
- Check redirect URLs in Supabase Auth settings
- Verify `site_url` matches your deployment URL
- Check browser console for errors

## Next Steps

- Read [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed deployment guide
- Read [scripts/README.md](./scripts/README.md) for script documentation
- Check [../infra/supabase/LOCAL_DEVELOPMENT.md](../infra/supabase/LOCAL_DEVELOPMENT.md) for database setup

