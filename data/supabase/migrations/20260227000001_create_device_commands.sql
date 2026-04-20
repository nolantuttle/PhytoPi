-- Migration: Create device_commands table for actuator control
-- Description: Adds a generic device_commands table to queue commands (e.g., toggle_light)
--              from users to devices, with basic RLS for ownership and device access.

CREATE TABLE IF NOT EXISTS public.device_commands (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id uuid NOT NULL REFERENCES public.device_units(id) ON DELETE CASCADE,
    command_type text NOT NULL,
    payload jsonb NOT NULL,
    status text NOT NULL DEFAULT 'pending', -- pending | executed | failed
    created_at timestamptz NOT NULL DEFAULT now(),
    executed_at timestamptz NULL
);

ALTER TABLE public.device_commands ENABLE ROW LEVEL SECURITY;

-- Users can enqueue commands for devices they own or have shared access to
CREATE POLICY "Users can queue device commands"
  ON public.device_commands
  FOR INSERT
  TO authenticated
  WITH CHECK (public.user_has_device_access(device_id, auth.uid()));

-- Users can view commands for their devices (for history / debugging)
CREATE POLICY "Users can view device commands"
  ON public.device_commands
  FOR SELECT
  TO authenticated
  USING (public.user_has_device_access(device_id, auth.uid()));

-- Devices (using anon or service role) can fetch commands.
-- NOTE: For now this trusts the device_id filter in the query.
CREATE POLICY "Devices can fetch commands"
  ON public.device_commands
  FOR SELECT
  TO anon
  USING (true);

-- Devices can update command status (executed / failed)
CREATE POLICY "Devices can update command status"
  ON public.device_commands
  FOR UPDATE
  TO anon
  USING (true);

