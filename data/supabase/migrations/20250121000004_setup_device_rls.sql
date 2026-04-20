-- Migration: Row Level Security for Device Onboarding Schema
-- Description: Sets up RLS policies for device ownership, sharing, and data access
-- Security Model:
--   - Owners can manage their devices (read/write)
--   - Sharees can view shared devices (read-only for viewers, read/write for admins)
--   - Device credentials and onboarding sessions are service-role only
--   - Readings can be inserted by authenticated devices, read by owners/sharees

-- Enable Row Level Security on all tables
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onboarding_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wifi_networks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sensor_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sensors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.readings ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- USER PROFILES
-- ============================================================================
-- Users can read their own profile, update their own profile

CREATE POLICY "Users can view own profile"
  ON public.user_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
  ON public.user_profiles FOR UPDATE
  USING (auth.uid() = user_id);

-- ============================================================================
-- PRODUCTS
-- ============================================================================
-- Products are publicly readable (catalog), but only service role can modify

CREATE POLICY "Anyone can view products"
  ON public.products FOR SELECT
  USING (true);

-- Products can only be modified by service role (no policy = service role only)

-- ============================================================================
-- DEVICE UNITS
-- ============================================================================
-- Device units are readable by owners and sharees
-- Only service role can insert/update (via Edge Functions)

CREATE POLICY "Owners can view their devices"
  ON public.device_units FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = device_units.id
      AND user_devices.user_id = auth.uid()
    )
  );

CREATE POLICY "Sharees can view shared devices"
  ON public.device_units FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.device_shares
      WHERE device_shares.device_id = device_units.id
      AND device_shares.shared_with = auth.uid()
      AND device_shares.accepted_at IS NOT NULL
    )
  );

-- Device units can only be inserted by service role (no policy = service role only)
-- UPDATE policies are added in migration 20250121000005_merge_devices_and_cleanup.sql
-- to allow owners and admins to update device name, location, status

-- ============================================================================
-- DEVICE CREDENTIALS
-- ============================================================================
-- Device credentials are service-role only (no RLS policies)
-- Devices authenticate via Edge Functions using device_key

-- ============================================================================
-- USER DEVICES
-- ============================================================================
-- Users can view devices they own
-- Only service role can insert (via Edge Functions during pairing)

CREATE POLICY "Users can view their device ownership"
  ON public.user_devices FOR SELECT
  USING (user_id = auth.uid());

-- User devices can only be inserted by service role (no policy = service role only)

-- ============================================================================
-- DEVICE SHARES
-- ============================================================================
-- Users can view shares for devices they own or are shared with
-- Owners and admins can manage shares

CREATE POLICY "Owners can view shares for their devices"
  ON public.device_shares FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = device_shares.device_id
      AND user_devices.user_id = auth.uid()
    )
  );

CREATE POLICY "Sharees can view their own shares"
  ON public.device_shares FOR SELECT
  USING (shared_with = auth.uid());

CREATE POLICY "Owners can create shares"
  ON public.device_shares FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = device_shares.device_id
      AND user_devices.user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can create shares"
  ON public.device_shares FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.device_shares AS ds
      WHERE ds.device_id = device_shares.device_id
      AND ds.shared_with = auth.uid()
      AND ds.role = 'admin'
      AND ds.accepted_at IS NOT NULL
    )
  );

CREATE POLICY "Owners can update shares"
  ON public.device_shares FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = device_shares.device_id
      AND user_devices.user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can update shares"
  ON public.device_shares FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.device_shares AS ds
      WHERE ds.device_id = device_shares.device_id
      AND ds.shared_with = auth.uid()
      AND ds.role = 'admin'
      AND ds.accepted_at IS NOT NULL
    )
  );

CREATE POLICY "Sharees can accept shares"
  ON public.device_shares FOR UPDATE
  USING (shared_with = auth.uid())
  WITH CHECK (shared_with = auth.uid());

CREATE POLICY "Owners can delete shares"
  ON public.device_shares FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = device_shares.device_id
      AND user_devices.user_id = auth.uid()
    )
  );

-- ============================================================================
-- ONBOARDING SESSIONS
-- ============================================================================
-- Onboarding sessions are service-role only (no RLS policies)
-- Managed entirely by Edge Functions during pairing flows

-- ============================================================================
-- WIFI NETWORKS
-- ============================================================================
-- Owners and admins can manage WiFi networks for their devices
-- Users can view WiFi networks for devices they own or are shared with (admin role)

CREATE POLICY "Owners can view WiFi networks for their devices"
  ON public.wifi_networks FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = wifi_networks.device_id
      AND user_devices.user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can view WiFi networks for shared devices"
  ON public.wifi_networks FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.device_shares
      WHERE device_shares.device_id = wifi_networks.device_id
      AND device_shares.shared_with = auth.uid()
      AND device_shares.role = 'admin'
      AND device_shares.accepted_at IS NOT NULL
    )
  );

CREATE POLICY "Owners can manage WiFi networks"
  ON public.wifi_networks FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = wifi_networks.device_id
      AND user_devices.user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage WiFi networks"
  ON public.wifi_networks FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.device_shares
      WHERE device_shares.device_id = wifi_networks.device_id
      AND device_shares.shared_with = auth.uid()
      AND device_shares.role = 'admin'
      AND device_shares.accepted_at IS NOT NULL
    )
  );

-- ============================================================================
-- SENSOR TYPES
-- ============================================================================
-- Sensor types are publicly readable (catalog), but only service role can modify

CREATE POLICY "Anyone can view sensor types"
  ON public.sensor_types FOR SELECT
  USING (true);

-- Sensor types can only be modified by service role (no policy = service role only)

-- ============================================================================
-- SENSORS
-- ============================================================================
-- Owners and sharees can view sensors for their devices
-- Owners and admins can manage sensors

CREATE POLICY "Owners can view sensors for their devices"
  ON public.sensors FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = sensors.device_id
      AND user_devices.user_id = auth.uid()
    )
  );

CREATE POLICY "Sharees can view sensors for shared devices"
  ON public.sensors FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.device_shares
      WHERE device_shares.device_id = sensors.device_id
      AND device_shares.shared_with = auth.uid()
      AND device_shares.accepted_at IS NOT NULL
    )
  );

CREATE POLICY "Owners can manage sensors"
  ON public.sensors FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = sensors.device_id
      AND user_devices.user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage sensors"
  ON public.sensors FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.device_shares
      WHERE device_shares.device_id = sensors.device_id
      AND device_shares.shared_with = auth.uid()
      AND device_shares.role = 'admin'
      AND device_shares.accepted_at IS NOT NULL
    )
  );

-- ============================================================================
-- READINGS
-- ============================================================================
-- Owners and sharees can view readings for their devices
-- Readings can be inserted by service role (device authentication via Edge Functions)
-- For device insertion, use service role or device-scoped JWT

CREATE POLICY "Owners can view readings for their devices"
  ON public.readings FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.sensors
      JOIN public.user_devices ON user_devices.device_id = sensors.device_id
      WHERE sensors.id = readings.sensor_id
      AND user_devices.user_id = auth.uid()
    )
  );

CREATE POLICY "Sharees can view readings for shared devices"
  ON public.readings FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.sensors
      JOIN public.device_shares ON device_shares.device_id = sensors.device_id
      WHERE sensors.id = readings.sensor_id
      AND device_shares.shared_with = auth.uid()
      AND device_shares.accepted_at IS NOT NULL
    )
  );

-- Readings can only be inserted by service role (no policy = service role only)
-- Devices authenticate via Edge Functions using device_key, then service role inserts readings

-- Helper function to check if user has access to a device
CREATE OR REPLACE FUNCTION public.user_has_device_access(device_uuid uuid, user_uuid uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.user_devices
    WHERE device_id = device_uuid AND user_id = user_uuid
  ) OR EXISTS (
    SELECT 1 FROM public.device_shares
    WHERE device_id = device_uuid
    AND shared_with = user_uuid
    AND accepted_at IS NOT NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.user_has_device_access IS 'Helper function to check if a user has access to a device (owner or sharee)';

