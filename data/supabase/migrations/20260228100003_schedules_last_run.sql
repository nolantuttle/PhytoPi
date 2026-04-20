-- Migration: Add last_run_at to schedules for UI display
-- Description: Pi can update last_run_at after executing a schedule.

ALTER TABLE public.schedules
  ADD COLUMN IF NOT EXISTS last_run_at timestamptz;

COMMENT ON COLUMN public.schedules.last_run_at IS 'Last time this schedule was executed (updated by Pi)';

-- RLS: Allow anon (Pi) to UPDATE schedules (for last_run_at only; Pi updates its device's schedules)
CREATE POLICY "Devices can update schedule last_run"
  ON public.schedules FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);
