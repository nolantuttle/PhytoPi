-- Plant preset RPC (basil) + per-user alert notification preferences for email/SMS delivery.

-- ---------------------------------------------------------------------------
-- Notification preferences (Edge Function reads with service role)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.alert_notification_settings (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email_enabled boolean NOT NULL DEFAULT true,
  sms_enabled boolean NOT NULL DEFAULT false,
  phone_e164 text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_alert_notification_settings_user ON public.alert_notification_settings(user_id);

ALTER TABLE public.alert_notification_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users select own notification settings"
  ON public.alert_notification_settings FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users insert own notification settings"
  ON public.alert_notification_settings FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users update own notification settings"
  ON public.alert_notification_settings FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users delete own notification settings"
  ON public.alert_notification_settings FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

COMMENT ON TABLE public.alert_notification_settings IS 'Per-user toggles for outbound alert email/SMS (notify-alert Edge Function).';

-- ---------------------------------------------------------------------------
-- apply_plant_preset: thresholds + schedules for indoor basil (example defaults)
-- ---------------------------------------------------------------------------
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
    INSERT INTO public.device_thresholds (device_id, metric, min_value, max_value, enabled)
    VALUES
      (p_device_id, 'soil_moisture', 35, 85, true),
      (p_device_id, 'temp_c', 18, 32, true),
      (p_device_id, 'humidity', 40, 75, true)
    ON CONFLICT (device_id, metric) DO UPDATE SET
      min_value = EXCLUDED.min_value,
      max_value = EXCLUDED.max_value,
      enabled = EXCLUDED.enabled,
      updated_at = now();

    DELETE FROM public.schedules
    WHERE device_id = p_device_id
      AND (payload->>'plant_preset') = 'basil';

    INSERT INTO public.schedules (device_id, schedule_type, cron_expr, interval_seconds, payload, enabled)
    VALUES
      (p_device_id, 'lights', '0 6', NULL,
       '{"state":true,"duration_sec":0,"plant_preset":"basil"}'::jsonb, true),
      (p_device_id, 'lights', '0 22', NULL,
       '{"state":false,"duration_sec":0,"plant_preset":"basil"}'::jsonb, true),
      (p_device_id, 'pump', NULL, 43200,
       '{"state":true,"duration_sec":25,"plant_preset":"basil"}'::jsonb, true);
  ELSE
    RAISE EXCEPTION 'unknown preset: %', p_preset;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.apply_plant_preset(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.apply_plant_preset(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.apply_plant_preset(uuid, text) IS 'Apply default thresholds/schedules for a plant preset (e.g. basil).';

-- Optional: attach a Database Webhook in Supabase Dashboard on public.alerts INSERT
-- targeting POST .../functions/v1/notify-alert with header Authorization: Bearer <NOTIFY_ALERT_SECRET>.
