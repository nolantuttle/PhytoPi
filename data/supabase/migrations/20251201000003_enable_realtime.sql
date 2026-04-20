-- Enable real-time for specific tables
-- This allows the dashboard to receive live updates

begin;

  -- Add tables to the publication
  -- We use drop first to ensure idempotency if rerun (though add table is usually fine, 
  -- explicit handling prevents "relation already in publication" errors if we were strict, 
  -- but "alter publication ... add table" will fail if it's already there. 
  -- Ideally we check if it's there.
  -- However, standard practice in simple migrations is just to add it. 
  -- To be safe and avoid errors on re-runs if the state is mixed, we can use a DO block or just ignore errors.
  -- But for Supabase migrations, usually we just run it.

  -- Check if table is already in publication not trivial in SQL script without dynamic SQL or DO block.
  -- Let's just add them. If they are already there, this might fail?
  -- Postgres "ALTER PUBLICATION ... ADD TABLE" does NOT have "IF NOT EXISTS".
  
  -- So we can use a DO block.

DO $$
BEGIN
  -- Enable for readings
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'readings' AND schemaname = 'public'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.readings;
  END IF;

  -- Enable for alerts
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'alerts' AND schemaname = 'public'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.alerts;
  END IF;

  -- Enable for device_units
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'device_units' AND schemaname = 'public'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.device_units;
  END IF;
END $$;

commit;

