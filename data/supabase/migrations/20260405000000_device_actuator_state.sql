-- Per-device actuator and sensor health state, upserted by the Pi firmware on transitions.
-- This lets the Flutter dashboard show "lights on since 06:00" etc. without polling device_commands.

CREATE TABLE IF NOT EXISTS public.device_actuator_state (
  device_id          uuid PRIMARY KEY REFERENCES public.device_units(id) ON DELETE CASCADE,
  lights_on          boolean NOT NULL DEFAULT false,
  pump_on            boolean NOT NULL DEFAULT false,
  fan_duty           int     NOT NULL DEFAULT 0,    -- 0–100 %
  lights_changed_at  timestamptz,
  pump_changed_at    timestamptz,
  fan_changed_at     timestamptz,
  bme_ok             boolean NOT NULL DEFAULT true,
  soil_ok            boolean NOT NULL DEFAULT true,
  updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_device_actuator_state_device ON public.device_actuator_state(device_id);

ALTER TABLE public.device_actuator_state ENABLE ROW LEVEL SECURITY;

-- Devices write via anon key (same pattern as alerts INSERT)
CREATE POLICY "Devices upsert actuator state"
  ON public.device_actuator_state FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

-- Owners/sharees can read
CREATE POLICY "Owners view actuator state"
  ON public.device_actuator_state FOR SELECT
  TO authenticated
  USING (
    device_id IN (
      SELECT device_id FROM public.user_devices
      WHERE user_id = auth.uid()
    )
  );

-- Enable realtime so the Flutter app gets instant updates
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND tablename = 'device_actuator_state'
      AND schemaname = 'public'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.device_actuator_state;
  END IF;
END $$;

COMMENT ON TABLE public.device_actuator_state IS 'Live actuator + sensor health state upserted by firmware on each transition.';
