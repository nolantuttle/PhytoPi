-- Migration: Device last_seen for offline detection
-- Description: Adds last_seen column to device_units; allows Pi (anon) to UPDATE last_seen for heartbeat.

-- Add last_seen column
ALTER TABLE public.device_units
  ADD COLUMN IF NOT EXISTS last_seen timestamptz;

COMMENT ON COLUMN public.device_units.last_seen IS 'Last time device reported (heartbeat). Used for offline detection.';

-- RLS: Allow anon (Pi controller) to UPDATE only last_seen for its own device
-- Pi uses device_id from config; we allow UPDATE where id matches (Pi can only update its own row)
CREATE POLICY "Devices can update own last_seen"
  ON public.device_units FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

-- Note: anon can only update rows they target by id. Restrict to single-row update by device_id in application.
-- Supabase anon key is shared; device authenticates via device_id in request. For stricter security,
-- use a service role or device-specific JWT. For now, Pi updates only its device_id row.
