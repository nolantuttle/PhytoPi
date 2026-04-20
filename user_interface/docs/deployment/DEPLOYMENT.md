# PhytoPi Dashboard Deployment Guide

This guide covers deploying the PhytoPi Dashboard to Vercel and other platforms.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [Vercel Deployment](#vercel-deployment)
- [Other Platforms](#other-platforms)
- [Environment Variables](#environment-variables)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- Flutter SDK (3.10.0 or higher)
- Supabase account and project
- Vercel account (for Vercel deployment)
- Git repository

## Local Development

### Quick Start

1. **Start Supabase locally:**
   ```bash
   cd infra/supabase
   supabase start
   ```

2. **Run the dashboard:**
   ```bash
   cd dashboard
   chmod +x scripts/run_local.sh
   ./scripts/run_local.sh
   ```

   Or manually:
   ```bash
   flutter run -d chrome --web-port 3000 \
     --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
     --dart-define=SUPABASE_ANON_KEY=<your-local-anon-key>
   ```

### Getting Local Anon Key

```bash
cd infra/supabase
supabase status
# Look for "anon key" in the output
```

## Vercel Deployment

### Method 1: Vercel CLI (Recommended)

1. **Install Vercel CLI:**
   ```bash
   npm install -g vercel
   ```

2. **Login to Vercel:**
   ```bash
   vercel login
   ```

3. **Link your project:**
   ```bash
   cd dashboard
   vercel link
   ```

4. **Set environment variables:**
   ```bash
   vercel env add SUPABASE_URL production
   vercel env add SUPABASE_ANON_KEY production
   ```

5. **Deploy:**
   ```bash
   vercel --prod
   ```

### Method 2: Vercel Dashboard

1. **Connect your repository:**
   - Go to [Vercel Dashboard](https://vercel.com/dashboard)
   - Click "Add New Project"
   - Import your Git repository
   - Select the `dashboard` directory as the root

2. **Configure build settings:**
   - **Framework Preset:** Other
   - **Root Directory:** `dashboard`
   - **Build Command:** `bash scripts/build.sh`
   - **Output Directory:** `build/web`
   - **Install Command:** (leave empty or use `echo 'Skipping install'`)

3. **Set environment variables:**
   - Go to Project Settings > Environment Variables
   - Add:
     - `SUPABASE_URL`: Your production Supabase URL
     - `SUPABASE_ANON_KEY`: Your production Supabase anon key

4. **Deploy:**
   - Click "Deploy"
   - Wait for build to complete

### Method 3: GitHub Actions (CI/CD)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Vercel

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'
          channel: 'stable'
      
      - name: Build Flutter Web
        run: |
          cd dashboard
          flutter pub get
          flutter build web --release \
            --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
            --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
      
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: ./dashboard
```

## Other Platforms

### Netlify

1. **Create `netlify.toml`:**
   ```toml
   [build]
     command = "bash scripts/build.sh"
     publish = "build/web"
   
   [[redirects]]
     from = "/*"
     to = "/index.html"
     status = 200
   ```

2. **Deploy:**
   - Connect repository to Netlify
   - Set environment variables in Netlify dashboard
   - Deploy

### Firebase Hosting

1. **Install Firebase CLI:**
   ```bash
   npm install -g firebase-tools
   ```

2. **Initialize Firebase:**
   ```bash
   firebase init hosting
   ```

3. **Create `firebase.json`:**
   ```json
   {
     "hosting": {
       "public": "build/web",
       "ignore": [
         "firebase.json",
         "**/.*",
         "**/node_modules/**"
       ],
       "rewrites": [
         {
           "source": "**",
           "destination": "/index.html"
         }
       ]
     }
   }
   ```

4. **Build and deploy:**
   ```bash
   ./scripts/build_prod.sh
   firebase deploy
   ```

### Static Hosting (GitHub Pages, etc.)

1. **Build locally:**
   ```bash
   export SUPABASE_URL=https://your-project.supabase.co
   export SUPABASE_ANON_KEY=your-anon-key
   ./scripts/build_prod.sh
   ```

2. **Deploy `build/web` directory:**
   - Upload to your hosting provider
   - Configure SPA routing (redirect all routes to index.html)

## Environment Variables

### Local Development

Create `.env.local` (gitignored):
```bash
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=your-local-anon-key
```

### Production

Set in your deployment platform:
- `SUPABASE_URL`: Your production Supabase project URL
- `SUPABASE_ANON_KEY`: Your production Supabase anon key

**Getting Production Keys:**
1. Go to your Supabase project dashboard
2. Navigate to Settings > API
3. Copy:
   - **Project URL** → `SUPABASE_URL`
   - **anon public** key → `SUPABASE_ANON_KEY`

## Supabase Configuration

### 1. Push Migrations to Production

```bash
cd infra/supabase
supabase link --project-ref your-project-ref
supabase db push
```

### 2. Configure Auth Redirect URLs

In Supabase Dashboard > Authentication > URL Configuration:
- **Site URL:** `https://your-vercel-app.vercel.app`
- **Redirect URLs:** 
  - `https://your-vercel-app.vercel.app/**`
  - `https://www.your-vercel-app.vercel.app/**`

### 3. Configure CORS (if needed)

If you encounter CORS issues, add your domain to Supabase:
- Settings > API > CORS
- Add your Vercel domain

## Troubleshooting

### Build Fails on Vercel

**Issue:** Flutter not found
**Solution:** The build script installs Flutter automatically. If it fails:
1. Check build logs for errors
2. Verify Flutter installation in build script
3. Consider using a Docker-based build

**Issue:** Environment variables not set
**Solution:** 
1. Verify environment variables in Vercel dashboard
2. Check that they're set for the correct environment (production, preview, development)

### App Can't Connect to Supabase

**Issue:** CORS errors
**Solution:**
1. Add your domain to Supabase CORS settings
2. Check that `SUPABASE_URL` is correct (should be `https://`, not `http://`)

**Issue:** Authentication redirect fails
**Solution:**
1. Verify redirect URLs in Supabase Auth settings
2. Check that `site_url` matches your deployment URL

### Build Size Too Large

**Issue:** Build output is very large
**Solution:**
1. Enable tree-shaking in Flutter (already enabled in release mode)
2. Remove unused dependencies
3. Use code splitting if needed
4. Optimize assets (images, fonts)

### Routing Issues (404 on refresh)

**Solution:** Already configured in `vercel.json` with rewrites. If using other platforms, ensure SPA routing is configured.

## Scripts Reference

### Local Development
```bash
./scripts/run_local.sh
```
- Starts Supabase locally
- Runs Flutter app with local configuration
- Auto-detects Supabase URL and anon key

### Production Build
```bash
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_ANON_KEY=your-anon-key
./scripts/build_prod.sh
```
- Builds Flutter app for production
- Requires environment variables
- Output: `build/web/`

### Vercel Build
```bash
./scripts/build.sh
```
- Used by Vercel during deployment
- Installs Flutter if needed
- Builds with environment variables from Vercel

## Next Steps

1. ✅ Set up Supabase production project
2. ✅ Push database migrations
3. ✅ Configure environment variables
4. ✅ Deploy to Vercel
5. ✅ Test authentication and data access
6. ✅ Set up custom domain (optional)
7. ✅ Configure monitoring and analytics

## Resources

- [Vercel Documentation](https://vercel.com/docs)
- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)
- [Supabase Documentation](https://supabase.com/docs)
- [Vercel Environment Variables](https://vercel.com/docs/concepts/projects/environment-variables)

