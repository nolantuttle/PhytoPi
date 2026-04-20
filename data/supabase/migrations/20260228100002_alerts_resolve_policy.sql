-- Migration: Allow device owners to resolve (close) alerts
-- Description: Adds RLS policy for authenticated users to UPDATE alerts (set resolved_at).

CREATE POLICY "Owners can resolve alerts"
  ON public.alerts FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = alerts.device_id
      AND user_devices.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_devices
      WHERE user_devices.device_id = alerts.device_id
      AND user_devices.user_id = auth.uid()
    )
  );

CREATE POLICY "Sharees can resolve alerts"
  ON public.alerts FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.device_shares
      WHERE device_shares.device_id = alerts.device_id
      AND device_shares.shared_with = auth.uid()
      AND device_shares.accepted_at IS NOT NULL
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.device_shares
      WHERE device_shares.device_id = alerts.device_id
      AND device_shares.shared_with = auth.uid()
      AND device_shares.accepted_at IS NOT NULL
    )
  );
