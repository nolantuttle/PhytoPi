-- Migration: Core Device Onboarding Tables
-- Description: Creates tables for user profiles, products, device units, credentials, and ownership
-- Supports: QR code pairing and kiosk mode onboarding flows

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
-- Note: gen_random_uuid() is built into PostgreSQL 13+, so uuid-ossp is not required

-- ============================================================================
-- USER PROFILES
-- ============================================================================
-- User profile information linked to Supabase auth.users
-- Each authenticated user has one profile record

CREATE TABLE public.user_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text,
  timezone text DEFAULT 'UTC',
  created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.user_profiles IS 'User profile information linked to Supabase authentication';
COMMENT ON COLUMN public.user_profiles.user_id IS 'References auth.users(id) - one profile per authenticated user';
COMMENT ON COLUMN public.user_profiles.timezone IS 'User timezone for displaying timestamps (default: UTC)';

-- ============================================================================
-- PRODUCTS
-- ============================================================================
-- Device catalog: defines product models and their features
-- Used for SKU-level behavior and device capabilities

CREATE TABLE public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sku text UNIQUE NOT NULL,
  name text NOT NULL,
  features jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.products IS 'Device catalog: product models and their capabilities';
COMMENT ON COLUMN public.products.sku IS 'Stock Keeping Unit - unique product identifier (e.g., PHYTOPI-MK1)';
COMMENT ON COLUMN public.products.features IS 'JSON object storing product-specific features and capabilities';

-- ============================================================================
-- DEVICE UNITS
-- ============================================================================
-- Manufactured device units with serial numbers and pairing codes
-- QR codes are generated from serial_number + pairing_code
-- Each device unit represents a physical device that can be claimed

CREATE TABLE public.device_units (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES public.products(id),
  serial_number text UNIQUE NOT NULL,
  pairing_code text NOT NULL,      -- one-time code; should be rotated on use
  pairing_expires_at timestamptz,  -- optional TTL for pairing code
  factory_data jsonb DEFAULT '{}', -- MAC addresses, PCB revision, QA stamps, etc.
  provisioned boolean DEFAULT false, -- true once device is claimed by a user
  created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.device_units IS 'Manufactured device units: physical devices with serial numbers and pairing codes';
COMMENT ON COLUMN public.device_units.serial_number IS 'Unique device serial number (e.g., PPI-24Q4-001234)';
COMMENT ON COLUMN public.device_units.pairing_code IS 'One-time pairing code for device claim (should be rotated after use)';
COMMENT ON COLUMN public.device_units.pairing_expires_at IS 'Optional expiration timestamp for pairing code';
COMMENT ON COLUMN public.device_units.factory_data IS 'Manufacturing data: MAC addresses, PCB revision, QA stamps, etc.';
COMMENT ON COLUMN public.device_units.provisioned IS 'True when device has been claimed by a user';

-- Index for fast lookup by serial number (used in pairing flow)
CREATE INDEX idx_device_units_serial_number ON public.device_units(serial_number);
CREATE INDEX idx_device_units_provisioned ON public.device_units(provisioned);

-- ============================================================================
-- DEVICE CREDENTIALS
-- ============================================================================
-- Rotatable secrets that device agents use to authenticate with APIs
-- Device key is stored as argon2id hash; plaintext only delivered once during pairing
-- This table should only be accessible via service role or Edge Functions

CREATE TABLE public.device_credentials (
  device_id uuid PRIMARY KEY REFERENCES public.device_units(id) ON DELETE CASCADE,
  device_key_hash text NOT NULL,   -- argon2id hash of device_key
  rotated_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.device_credentials IS 'Device authentication credentials: rotatable secrets for API access';
COMMENT ON COLUMN public.device_credentials.device_key_hash IS 'Argon2id hash of the device key (plaintext only delivered once during pairing)';
COMMENT ON COLUMN public.device_credentials.rotated_at IS 'Timestamp of last credential rotation';

-- ============================================================================
-- USER DEVICES
-- ============================================================================
-- Ownership link between users and devices
-- A user can own many devices; a device has one owner
-- This table drives RLS policies for device access

CREATE TABLE public.user_devices (
  user_id uuid REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
  device_id uuid REFERENCES public.device_units(id) ON DELETE CASCADE,
  claimed_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, device_id)
);

COMMENT ON TABLE public.user_devices IS 'Device ownership: links users to their claimed devices';
COMMENT ON COLUMN public.user_devices.claimed_at IS 'Timestamp when user claimed the device';

-- Indexes for efficient ownership queries
CREATE INDEX idx_user_devices_user_id ON public.user_devices(user_id);
CREATE INDEX idx_user_devices_device_id ON public.user_devices(device_id);

