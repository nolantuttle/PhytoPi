# Google OAuth setup for PhytoPi (local + mobile)

The app uses **Sign in with Google**. Supabase must have the Google provider enabled and valid OAuth credentials. The error `"Unsupported provider: provider is not enabled"` means Google is not enabled or credentials are missing.

## 1. Create Google OAuth credentials

1. Open [Google Cloud Console](https://console.cloud.google.com/) and select or create a project.
2. Go to **APIs & Services** → **Credentials** → **Create credentials** → **OAuth client ID**.
3. If prompted, configure the **OAuth consent screen** (User type: External, add app name and support email).
4. Create an **OAuth 2.0 Client ID**:
   - Application type: **Web application** (for local Supabase callback).
   - Name: e.g. `PhytoPi Local`.
   - **Authorized JavaScript origins** (add both for local + phone testing):
     - `http://127.0.0.1:54321`
     - `http://192.168.0.39:54321` (use your computer’s LAN IP; get it with `ip addr show | grep 'inet ' | grep -v 127.0.0.1`)
   - **Authorized redirect URIs** (Supabase Auth callback):
     - `http://127.0.0.1:54321/auth/v1/callback`
     - `http://192.168.0.39:54321/auth/v1/callback` (same LAN IP as above)
5. Click **Create** and copy the **Client ID** and **Client Secret**.

**Scopes:** Ensure the consent screen has at least `email`, `profile`, and `openid` (default OAuth client usually includes these).

## 2. Set environment variables for Supabase

Supabase reads Google credentials from the environment. Set them **before** starting Supabase.

**Option A – export in the same terminal where you run Supabase**

```bash
export SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID="your-client-id.apps.googleusercontent.com"
export SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_SECRET="your-client-secret"
```

**Option B – use a `.env` file in the Supabase directory**

Create `Data_Infraestructure/supabase/.env` (and add it to `.gitignore` if not already):

```bash
SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_SECRET=your-client-secret
```

Then load it when starting Supabase, e.g.:

```bash
cd Data_Infraestructure/supabase
set -a && source .env && set +a
supabase start
```

**Option C – systemd / user env (e.g. for a service)**

Set the same two variables in the environment that runs `supabase start`.

## 3. Restart Supabase

After enabling Google in `config.toml` and setting the env vars, restart so Auth picks up the change:

```bash
cd Data_Infraestructure/supabase
supabase stop
supabase start
```

## 4. Confirm redirect URLs in Supabase

In `config.toml`, `[auth]` should allow your app’s redirect URLs. The repo already includes:

- `com.example.phytopidashboard://login-callback` (mobile app deep link)

If you use a custom site URL or extra redirects, add them to `additional_redirect_urls` under `[auth]`.

## 5. Test Google sign-in

- **Web:** Open the app in the browser and click Sign in with Google.
- **Mobile (Android):** Run the app on device/emulator; ensure the device can reach your machine’s Supabase URL (e.g. `http://192.168.0.39:54321` in `.env.local`). Use the same IP in Google Console redirect URIs and JavaScript origins as in step 1.

## Troubleshooting

| Issue | What to do |
|-------|------------|
| `Unsupported provider: provider is not enabled` | Google is disabled or env vars are missing. Set `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` and `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_SECRET`, then `supabase stop` and `supabase start`. |
| Redirect URI mismatch | In Google Console, the redirect URI must be exactly `http://<host>:54321/auth/v1/callback` (same host/port as your Supabase API URL). |
| Mobile can’t reach Supabase | Use your computer’s LAN IP in the app config and in Google (e.g. `http://192.168.0.39:54321`). Phone and PC must be on the same network. |

## References

- [Supabase: Login with Google](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Supabase: Managing config and secrets (local)](https://supabase.com/docs/guides/local-development/managing-config)
