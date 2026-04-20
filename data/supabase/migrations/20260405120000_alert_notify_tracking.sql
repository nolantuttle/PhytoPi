-- Track outbound alert notifications so we can backfill safely and avoid duplicate emails on retry.

ALTER TABLE public.alerts
  ADD COLUMN IF NOT EXISTS email_notified_at timestamptz,
  ADD COLUMN IF NOT EXISTS sms_notified_at timestamptz,
  ADD COLUMN IF NOT EXISTS notify_completed_at timestamptz;

COMMENT ON COLUMN public.alerts.email_notified_at IS 'Set when email notification was sent successfully for this alert (notify-alert Edge Function).';
COMMENT ON COLUMN public.alerts.sms_notified_at IS 'Set when SMS was sent successfully for this alert.';
COMMENT ON COLUMN public.alerts.notify_completed_at IS 'Set when all channels the user wants (email/SMS) are satisfied or not applicable.';

CREATE INDEX IF NOT EXISTS idx_alerts_pending_notify
  ON public.alerts (triggered_at)
  WHERE notify_completed_at IS NULL AND resolved_at IS NULL;
