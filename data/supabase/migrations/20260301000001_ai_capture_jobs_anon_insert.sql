-- Fix: Ensure anon (Pi / device) can INSERT into ai_capture_jobs.
-- Run this in Supabase SQL Editor if you get "new row violates row-level security policy"
-- when the capture script tries to create a job.
--
-- Both are required: (1) GRANT so anon has table privilege, (2) RLS policy so the row is allowed.

GRANT USAGE ON SCHEMA public TO anon;
GRANT INSERT ON public.ai_capture_jobs TO anon;

DROP POLICY IF EXISTS "Devices can insert ai_capture_jobs" ON public.ai_capture_jobs;
CREATE POLICY "Devices can insert ai_capture_jobs"
  ON public.ai_capture_jobs FOR INSERT
  TO anon
  WITH CHECK (true);
