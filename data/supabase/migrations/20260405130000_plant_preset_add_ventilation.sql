-- Migration: Extend apply_plant_preset (basil) with a ventilation schedule.
-- Also adds fan_duty threshold support note (no threshold row in preset — user-driven).
-- Re-creates the function so apply is idempotent on re-run.

CREATE OR REPLACE FUNCTION public.apply_plant_preset(p_device_id uuid, p_preset text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.user_devices
    WHERE user_devices.device_id = p_device_id
      AND user_devices.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'device not found or access denied';
  END IF;

  IF lower(trim(p_preset)) = 'basil' THEN
    -- Thresholds: soil moisture, temperature, humidity
    INSERT INTO public.device_thresholds (device_id, metric, min_value, max_value, enabled)
    VALUES
      (p_device_id, 'soil_moisture', 35, 85, true),
      (p_device_id, 'temp_c',        18, 32, true),
      (p_device_id, 'humidity',      40, 75, true)
    ON CONFLICT (device_id, metric) DO UPDATE SET
      min_value  = EXCLUDED.min_value,
      max_value  = EXCLUDED.max_value,
      enabled    = EXCLUDED.enabled,
      updated_at = now();

    -- Remove any previously applied basil schedules before re-inserting
    DELETE FROM public.schedules
    WHERE device_id = p_device_id
      AND (payload->>'plant_preset') = 'basil';

    -- Schedules: lights on at 06:00, off at 22:00; pump every 12 h for 25 s;
    -- ventilation every 2 h for 5 min at 80 % duty (interval-based, always-on state)
    INSERT INTO public.schedules
      (device_id, schedule_type, cron_expr, interval_seconds, payload, enabled)
    VALUES
      (p_device_id, 'lights',      '0 6',  NULL,
       '{"state":true,"duration_sec":0,"plant_preset":"basil"}'::jsonb,         true),
      (p_device_id, 'lights',      '0 22', NULL,
       '{"state":false,"duration_sec":0,"plant_preset":"basil"}'::jsonb,        true),
      (p_device_id, 'pump',        NULL,   43200,
       '{"state":true,"duration_sec":25,"plant_preset":"basil"}'::jsonb,        true),
      (p_device_id, 'ventilation', NULL,   7200,
       '{"state":true,"duration_sec":300,"duty_percent":80,"plant_preset":"basil"}'::jsonb, true);
  ELSE
    RAISE EXCEPTION 'unknown preset: %', p_preset;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.apply_plant_preset(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.apply_plant_preset(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.apply_plant_preset(uuid, text) IS
  'Apply default thresholds/schedules for a plant preset (basil). '
  'Ventilation: every 2 h for 5 min at 80 % duty. '
  'Fan duty thresholds are not set by preset — add them manually or use "Fill from recent data".';
