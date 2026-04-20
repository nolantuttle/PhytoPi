-- Migration: Add claim_device_by_serial RPC
-- Description: Allows users to claim a device by its serial number

CREATE OR REPLACE FUNCTION public.claim_device_by_serial(serial_text text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER -- Run as creator (usually postgres/admin) to bypass RLS
AS $$
DECLARE
  v_device_id uuid;
  v_device_record record;
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Find the device
  SELECT * INTO v_device_record
  FROM public.device_units
  WHERE serial_number = serial_text;

  IF v_device_record IS NULL THEN
    RAISE EXCEPTION 'Device not found';
  END IF;

  -- Check if already claimed by THIS user
  IF EXISTS (SELECT 1 FROM public.user_devices WHERE user_id = v_user_id AND device_id = v_device_record.id) THEN
    RETURN to_jsonb(v_device_record);
  END IF;

  -- Check if claimed by SOMEONE ELSE
  -- Only throw error if provisioned AND actually has an owner (prevents locking out orphaned devices)
  IF v_device_record.provisioned THEN
     IF EXISTS (SELECT 1 FROM public.user_devices WHERE device_id = v_device_record.id) THEN
        RAISE EXCEPTION 'Device already claimed';
     END IF;
  END IF;

  -- Claim it
  INSERT INTO public.user_devices (user_id, device_id)
  VALUES (v_user_id, v_device_record.id);

  -- Update device status
  UPDATE public.device_units
  SET provisioned = true,
      registered_at = COALESCE(registered_at, now()),
      updated_at = now()
  WHERE id = v_device_record.id
  RETURNING * INTO v_device_record;

  RETURN to_jsonb(v_device_record);
END;
$$;
