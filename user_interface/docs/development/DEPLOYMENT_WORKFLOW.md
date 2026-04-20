# Deployment Workflow

End-to-end workflow for taking changes from development through testing and production releases across **web (Vercel)**, **mobile (Android/iOS)**, and **kiosk (Raspberry Pi)** targets.

---

## Environments

| Stage        | Purpose                        | Supabase Project          | Notes                                               |
|--------------|--------------------------------|---------------------------|-----------------------------------------------------|
| Development  | Local feature work             | `dev` project / local CLI | `.env.local`, `.env.android`, `.env.kiosk`          |
| Staging      | PR verification & smoke tests  | `staging` project         | Vercel preview, Firebase Test Lab / TestFlight      |
| Production   | Customer-facing deployments    | `prod` project            | Vercel production, Play/App Store, kiosk OTA bucket |

---

## Release Pipeline Overview

1. **Development Stage**
   - Feature branches off `main`.
   - Local scripts:
     - Web: `./scripts/dev/run_local.sh`
     - Android device/emulator: `./scripts/dev/test_android*.sh`
     - Kiosk quick test: `./scripts/dev/test_kiosk.sh --pi5 <host>`
   - Supabase migrations via `infra/supabase`.
   - Flutter unit/widget tests (`flutter test`).

2. **Testing / CI Stage**
   - PR pipelines (GitHub Actions or similar):
     1. Format + lint: `flutter format`, `flutter analyze`.
     2. Tests: `flutter test`, `supabase db lint`.
     3. Build validation: `flutter build web`, `flutter build apk`, `flutter build linux`.
   - Staging deploys:
     - Web → Vercel preview linked to PR.
     - Android/iOS → internal testing tracks (Firebase App Distribution, TestFlight).
     - Kiosk → staging Pi using `update_kiosk.sh --channel staging`.

3. **Production Stage**
   - Merge PR → tag release (e.g., `web-v1.2.0`, `mobile-v1.2.0`, `kiosk-v1.2.0`).
   - Platform-specific deployments (details below).
   - Update Supabase env vars / secrets as needed.
   - Monitor health (Vercel analytics, Play/App Store console, kiosk fleet logs).

---

## Platform-Specific Release Steps

### Web (Vercel)
1. Merge to `main` triggers Vercel production build (or deploy via CLI).
2. Ensure `VERCEL_ENV=production` with correct `SUPABASE_URL` + `SUPABASE_ANON_KEY`.
3. Optional: `vercel deploy --prod` tied to release tags.

### Mobile
1. Bump `version` + `build` in `pubspec.yaml`.
2. **Android**
   - `./scripts/build/build_mobile_android.sh appbundle`
   - Upload `app-release.aab` to Play Console (internal → closed → production tracks).
3. **iOS**
   - `./scripts/build/build_mobile_ios.sh`
   - Archive & notarize via Xcode / `xcodebuild`, upload to App Store Connect.
4. Publish release notes referencing Supabase schema version + kiosk compatibility.

### Kiosk (Raspberry Pi)
1. Build ARM64 bundle on Pi build runner:
   ```bash
   flutter build linux --release \
     --dart-define=KIOSK_MODE=true \
     --dart-define=SUPABASE_URL="https://prod.supabase.co" \
     --dart-define=SUPABASE_ANON_KEY="******"
   ```
2. Package + checksum:
   ```bash
   tar -czf phytopi-kiosk-arm64-v1.2.0.tar.gz -C build/linux/arm64/release bundle
   shasum -a 256 phytopi-kiosk-arm64-v1.2.0.tar.gz > phytopi-kiosk-arm64-v1.2.0.sha256
   ```
3. Upload artifact to release storage (Supabase bucket/S3/GitHub release).
4. Update OTA endpoint consumed by `update_kiosk.sh`.
5. Rollout strategy:
   - Stage 1: Lab Pi(s)
   - Stage 2: Pilot customers
   - Stage 3: Fleet

---

## OTA Update Flow for Kiosks

1. **Update Script (`update_kiosk.sh`)**
   - Downloads latest tarball + checksum.
   - Verifies signature.
   - Stops `phytopi-kiosk.service`.
   - Backs up existing bundle.
   - Deploys new bundle, restarts service.

2. **Agent-triggered Updates**
   - Sensor agent polls update API (e.g., Supabase `device_updates` table).
   - When `version > current`, executes update script.

3. **Monitoring**
   - `systemd` logs (`journalctl -u phytopi-kiosk.service`).
   - Health pings back to Supabase (device heartbeat table).

---

## Automation & CI/CD Tips

| Job                     | Trigger        | Actions                                                                 |
|------------------------|----------------|-------------------------------------------------------------------------|
| `lint-test`            | PR             | Format, lint, Flutter tests, Supabase lint                              |
| `build-check`          | PR             | `flutter build web`, `apk`, `linux` (no artifacts)                      |
| `deploy-web`           | Tag `web-*`    | Trigger Vercel prod deploy (if not automatic)                           |
| `build-mobile-artifacts` | Tag `mobile-*` | Produce `.aab` / `.ipa` artifacts, attach to release                    |
| `build-kiosk-arm64`    | Tag `kiosk-*`  | Run on ARM64 runner, upload tarball + checksum, notify OTA endpoint     |

---

## Security & Rollback

- **Environment Isolation**: separate Supabase keys per environment; never ship service-role keys in kiosk/mobile/web apps.
- **Rollback**:
  - Web: revert deployment in Vercel.
  - Mobile: promote previous store version or halt rollout.
  - Kiosk: `update_kiosk.sh --version vPrevious` (download archived tarball) or restore backup bundle.
- **Monitoring**:
  - Web/mobile: analytics/error reporting (Sentry, Firebase Crashlytics).
  - Kiosk: systemd logs + Supabase heartbeat table.

---

## Kiosk OS Provisioning & Claim Flow

### Golden Image Strategy
- Build a locked-down OS image (Yocto, Buildroot, BalenaOS, or Debian derivative) that contains only the kiosk Flutter bundle, watchdog, OTA agent, and telemetry.
- Keep the root filesystem read-only, provide a separate writable data partition, and disable all unused services.
- Auto-login a `kiosk` user into fullscreen mode without shell access; run the app under this user with minimal permissions.
- Flash devices in the factory with this “golden image”, then inject a unique device identifier plus an X.509 cert/private key into a root-owned encrypted partition (seal with TPM/secure element when hardware supports it).

### Claiming a Device
1. First boot starts in claim mode and displays a QR code `https://api.phytopi.com/claim/{deviceId}` that includes a short-lived challenge token; the kiosk UI also exposes login/register.
2. The user either signs in on the kiosk or scans the QR code from their phone. The backend verifies identity, confirms the device is unclaimed, and binds `deviceId` to the user account.
3. After verification the backend issues a scoped device token (JWT or client cert) tied to that owner, and the kiosk swaps from claim mode into normal operation.
4. Subsequent API calls are authorized with the scoped token, so backend row-level security enforces per-user isolation automatically.

### Keeping Secrets Off the Device
- Never bake Supabase anon/service keys or database credentials into the firmware image.
- Ship only the factory cert + challenge. After claim, request short-lived, least-privilege tokens from a backend endpoint and store them inside the encrypted partition.
- Expose only revocable tokens to the kiosk process; rotate them regularly and revoke remotely if a device is reported stolen.
- Mount `/app` as read-only, block TTY switching and USB mass storage, and keep the kiosk user non-privileged so local access cannot leak secrets.

### Additional Safeguards
- Enable secure boot / measured boot so modified images refuse to start or are flagged to the backend.
- Sign OTA updates from CI/CD; the updater verifies signatures before applying and can roll back to the previous bundle automatically.
- Maintain tamper and health logs (signed) that are reported back to Supabase; alert if filesystem integrity checks fail.
- Document the claim/reset SOP so support can unbind a device, wipe tokens, and return it to factory state safely.

---

## Checklist Summary

1. **Before release**
   - ✅ Tests pass
   - ✅ Supabase migrations applied
   - ✅ Version bumped
   - ✅ Release notes drafted

2. **Deploy**
   - 🌐 Web → Vercel production
   - 📱 Mobile → Play/App Store
   - 🖥️ Kiosk → OTA tarball published + update triggered

3. **After release**
   - 🔍 Monitor logs & metrics
   - 📣 Communicate rollout status
   - 📦 Tag repository with released versions




