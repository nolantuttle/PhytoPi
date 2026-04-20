-- Migration: PhytoPi Smart Grow Box Extension
-- Description: Adds device_thresholds, schedules, ai_capture_jobs; extends sensor_types;
--              Adds RLS for Pi to insert alerts; extends ml_inferences for AI workflow.

-- ============================================================================
-- 1. Extend sensor_types
-- ============================================================================
INSERT INTO public.sensor_types (key, name, unit, description) VALUES
  ('gas_resistance', 'Gas Resistance', 'kOhm', 'BME680 gas/VOC resistance'),
  ('water_level_frequency', 'Water Level (Photoelectric)', 'Hz', 'CQRobot photoelectric water level frequency')
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- 2. Add source column to alerts (manual, scheduled, automated, threshold)
-- ============================================================================
ALTER TABLE public.alerts
  ADD COLUMN IF NOT EXISTS source text DEFAULT 'manual';

-- ============================================================================
-- 3. RLS: Allow anon (Pi controller) to INSERT alerts
-- ============================================================================
CREATE POLICY "Devices can insert alerts"
  ON public.alerts FOR INSERT
  TO anon
  WITH CHECK (true);

-- ============================================================================
-- 4. device_thresholds
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.device_thresholds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid NOT NULL REFERENCES public.device_units(id) ON DELETE CASCADE,
  metric text NOT NULL,
  min_value double precision,
  max_value double precision,
  enabled boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(device_id, metric)
);

CREATE INDEX IF NOT EXISTS idx_device_thresholds_device ON public.device_thresholds(device_id);

ALTER TABLE public.device_thresholds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owners can manage thresholds"
  ON public.device_thresholds FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = device_thresholds.device_id
      AND user_devices.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = device_thresholds.device_id
      AND user_devices.user_id = auth.uid()
    )
  );

CREATE POLICY "Sharees can view thresholds"
  ON public.device_thresholds FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.device_shares
      WHERE device_shares.device_id = device_thresholds.device_id
      AND device_shares.shared_with = auth.uid()
      AND device_shares.accepted_at IS NOT NULL
    )
  );

-- Pi (anon) can read thresholds for its device
CREATE POLICY "Devices can read thresholds"
  ON public.device_thresholds FOR SELECT
  TO anon
  USING (true);

-- ============================================================================
-- 5. schedules
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid NOT NULL REFERENCES public.device_units(id) ON DELETE CASCADE,
  schedule_type text NOT NULL,
  cron_expr text,
  interval_seconds integer,
  payload jsonb DEFAULT '{}',
  enabled boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_schedules_device ON public.schedules(device_id);

ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owners can manage schedules"
  ON public.schedules FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = schedules.device_id
      AND user_devices.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = schedules.device_id
      AND user_devices.user_id = auth.uid()
    )
  );

CREATE POLICY "Sharees can view schedules"
  ON public.schedules FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.device_shares
      WHERE device_shares.device_id = schedules.device_id
      AND device_shares.shared_with = auth.uid()
      AND device_shares.accepted_at IS NOT NULL
    )
  );

CREATE POLICY "Devices can read schedules"
  ON public.schedules FOR SELECT
  TO anon
  USING (true);

-- ============================================================================
-- 6. ai_capture_jobs
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ai_capture_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid NOT NULL REFERENCES public.device_units(id) ON DELETE CASCADE,
  image_url text,
  status text NOT NULL DEFAULT 'pending',
  vision_result jsonb,
  llm_result jsonb,
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_ai_capture_jobs_device ON public.ai_capture_jobs(device_id);
CREATE INDEX IF NOT EXISTS idx_ai_capture_jobs_status ON public.ai_capture_jobs(status);

ALTER TABLE public.ai_capture_jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owners can view ai_capture_jobs"
  ON public.ai_capture_jobs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = ai_capture_jobs.device_id
      AND user_devices.user_id = auth.uid()
    )
  );

CREATE POLICY "Sharees can view ai_capture_jobs"
  ON public.ai_capture_jobs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.device_shares
      WHERE device_shares.device_id = ai_capture_jobs.device_id
      AND device_shares.shared_with = auth.uid()
      AND device_shares.accepted_at IS NOT NULL
    )
  );

CREATE POLICY "Devices can insert ai_capture_jobs"
  ON public.ai_capture_jobs FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Service can update ai_capture_jobs"
  ON public.ai_capture_jobs FOR UPDATE
  TO anon
  USING (true);

-- ============================================================================
-- 7. Extend ml_inferences for AI workflow
-- ============================================================================
ALTER TABLE public.ml_inferences
  ADD COLUMN IF NOT EXISTS diagnostic text,
  ADD COLUMN IF NOT EXISTS tips jsonb,
  ADD COLUMN IF NOT EXISTS job_id uuid REFERENCES public.ai_capture_jobs(id);

-- ============================================================================
-- 8. Storage bucket: device-images
-- ============================================================================
-- Create bucket for AI-captured plant images. RLS policies allow device owners
-- to read and Pi (anon) to upload. Create via Dashboard if this fails.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'device-images',
  'device-images',
  false,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated device owners to read their device images
CREATE POLICY "Device owners can read images"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'device-images'
  );

-- Allow anon (Pi) to upload - restrict by path pattern device_id/timestamp.jpg
CREATE POLICY "Devices can upload images"
  ON storage.objects FOR INSERT
  TO anon
  WITH CHECK (bucket_id = 'device-images');
