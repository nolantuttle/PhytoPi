-- Migration: Allow anonymous inserts for readings
-- Description: Allows devices using the Anon Key to insert sensor readings directly
-- Note: This is useful for devices that don't have a specific device identity or when using a simpler auth model

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
        AND tablename = 'readings'
        AND policyname = 'Allow anon insert readings'
    ) THEN
        CREATE POLICY "Allow anon insert readings"
        ON public.readings
        FOR INSERT
        TO anon
        WITH CHECK (true);
    END IF;
END
$$;
