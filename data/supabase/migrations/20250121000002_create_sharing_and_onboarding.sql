-- Migration: Device Sharing and Onboarding
-- Description: Creates tables for device sharing, onboarding sessions, and WiFi networks
-- Supports: QR code pairing, kiosk mode, device sharing with roles

-- ============================================================================
-- DEVICE SHARES
-- ============================================================================
-- Shared access to devices with viewer/admin roles
-- Allows users to share device access without transferring ownership

CREATE TABLE public.device_shares (
  device_id uuid REFERENCES public.device_units(id) ON DELETE CASCADE,
  shared_with uuid REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
  role text CHECK (role IN ('viewer', 'admin')) NOT NULL DEFAULT 'viewer',
  invited_at timestamptz DEFAULT now(),
  accepted_at timestamptz,
  PRIMARY KEY (device_id, shared_with)
);

COMMENT ON TABLE public.device_shares IS 'Device sharing: allows users to share device access with others';
COMMENT ON COLUMN public.device_shares.role IS 'Access role: viewer (read-only) or admin (can manage shares, WiFi, etc.)';
COMMENT ON COLUMN public.device_shares.invited_at IS 'Timestamp when share was created';
COMMENT ON COLUMN public.device_shares.accepted_at IS 'Timestamp when sharee accepted the invitation (NULL if pending)';

-- Indexes for efficient share queries
CREATE INDEX idx_device_shares_device_id ON public.device_shares(device_id);
CREATE INDEX idx_device_shares_shared_with ON public.device_shares(shared_with);
CREATE INDEX idx_device_shares_accepted ON public.device_shares(accepted_at) WHERE accepted_at IS NOT NULL;

-- ============================================================================
-- ONBOARDING SESSIONS
-- ============================================================================
-- Ephemeral sessions for both QR code and kiosk mode pairing
-- Supports short codes for kiosk displays and session-based verification

CREATE TABLE public.onboarding_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid REFERENCES public.device_units(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.user_profiles(user_id), -- set after user signs in (QR flow) or verifies (kiosk flow)
  short_code text,                 -- optional human-typed code shown by kiosk (e.g., "AB1C")
  status text CHECK (status IN ('pending', 'verified', 'consumed')) DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz NOT NULL
);

COMMENT ON TABLE public.onboarding_sessions IS 'Ephemeral onboarding sessions for QR code and kiosk mode pairing';
COMMENT ON COLUMN public.onboarding_sessions.device_id IS 'Device being onboarded';
COMMENT ON COLUMN public.onboarding_sessions.user_id IS 'User claiming the device (set after authentication)';
COMMENT ON COLUMN public.onboarding_sessions.short_code IS 'Short human-readable code for kiosk display (optional)';
COMMENT ON COLUMN public.onboarding_sessions.status IS 'Session status: pending (created), verified (user authenticated), consumed (device claimed)';
COMMENT ON COLUMN public.onboarding_sessions.expires_at IS 'Session expiration timestamp';

-- Indexes for session lookup and cleanup
CREATE INDEX idx_onboarding_sessions_device_id ON public.onboarding_sessions(device_id);
CREATE INDEX idx_onboarding_sessions_user_id ON public.onboarding_sessions(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_onboarding_sessions_short_code ON public.onboarding_sessions(short_code) WHERE short_code IS NOT NULL;
CREATE INDEX idx_onboarding_sessions_status ON public.onboarding_sessions(status);
CREATE INDEX idx_onboarding_sessions_expires_at ON public.onboarding_sessions(expires_at);

-- ============================================================================
-- WIFI NETWORKS
-- ============================================================================
-- WiFi network profiles queued for devices to fetch after verification
-- Passphrases should be encrypted (e.g., using pgcrypto) or delivered via Edge Functions only
-- Devices fetch WiFi configs via authenticated API calls

CREATE TABLE public.wifi_networks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid REFERENCES public.device_units(id) ON DELETE CASCADE,
  ssid text NOT NULL,
  passphrase_encrypted text,       -- encrypted passphrase (use pgcrypto)
  created_by uuid REFERENCES public.user_profiles(user_id),
  created_at timestamptz DEFAULT now(),
  fetched_at timestamptz,          -- timestamp when device fetched this WiFi config
  UNIQUE(device_id, ssid)          -- one WiFi config per device per SSID
);

COMMENT ON TABLE public.wifi_networks IS 'WiFi network profiles for devices: queued for devices to fetch after verification';
COMMENT ON COLUMN public.wifi_networks.ssid IS 'WiFi network name';
COMMENT ON COLUMN public.wifi_networks.passphrase_encrypted IS 'Encrypted WiFi passphrase (use pgcrypto encrypt function)';
COMMENT ON COLUMN public.wifi_networks.created_by IS 'User who added this WiFi network';
COMMENT ON COLUMN public.wifi_networks.fetched_at IS 'Timestamp when device fetched this WiFi config (NULL if not yet fetched)';

-- Indexes for WiFi network queries
CREATE INDEX idx_wifi_networks_device_id ON public.wifi_networks(device_id);
CREATE INDEX idx_wifi_networks_created_by ON public.wifi_networks(created_by);
CREATE INDEX idx_wifi_networks_fetched ON public.wifi_networks(fetched_at) WHERE fetched_at IS NULL;

-- Function to automatically create user profile on first auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.user_profiles (user_id, full_name)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create user profile when auth user is created
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

COMMENT ON FUNCTION public.handle_new_user() IS 'Automatically creates user profile when a new auth user is created';

