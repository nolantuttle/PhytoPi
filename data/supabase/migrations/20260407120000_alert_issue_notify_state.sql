-- Alert issue notification state (email/SMS dedupe + escalation).
-- Purpose: prevent notification spam/quota drain by allowing:
--   1) one normal notification per (device_id, issue_key)
--   2) one escalation notification while still unresolved
--   3) suppress further notifications until issue is resolved

CREATE TABLE IF NOT EXISTS public.alert_issue_notify_state (
  device_id uuid NOT NULL REFERENCES public.device_units(id) ON DELETE CASCADE,
  issue_key text NOT NULL,
  first_alert_id uuid REFERENCES public.alerts(id) ON DELETE SET NULL,
  notify_stage integer NOT NULL DEFAULT 0, -- 0=never, 1=normal sent, 2=escalated sent
  last_alert_at timestamptz NOT NULL DEFAULT now(),
  normal_emailed_at timestamptz,
  red_emailed_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (device_id, issue_key)
);

COMMENT ON TABLE public.alert_issue_notify_state IS 'Per-device, per-issue notification stage for alert outbound channels (dedupe + escalation).';
COMMENT ON COLUMN public.alert_issue_notify_state.issue_key IS 'Stable key identifying the issue (usually alerts.type).';
COMMENT ON COLUMN public.alert_issue_notify_state.notify_stage IS '0=never notified, 1=normal notified, 2=escalated notified; suppress beyond 2 until resolution.';

CREATE INDEX IF NOT EXISTS idx_alert_issue_notify_state_device
  ON public.alert_issue_notify_state (device_id);

CREATE INDEX IF NOT EXISTS idx_alert_issue_notify_state_updated
  ON public.alert_issue_notify_state (updated_at);

ALTER TABLE public.alert_issue_notify_state ENABLE ROW LEVEL SECURITY;
-- No RLS policies: service role only.

CREATE OR REPLACE FUNCTION public.alert_issue_notify_state_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_alert_issue_notify_state_updated_at ON public.alert_issue_notify_state;
CREATE TRIGGER trg_alert_issue_notify_state_updated_at
  BEFORE UPDATE ON public.alert_issue_notify_state
  FOR EACH ROW
  EXECUTE FUNCTION public.alert_issue_notify_state_touch_updated_at();

-- Reset notification stage when an alert is resolved.
CREATE OR REPLACE FUNCTION public.clear_alert_issue_notify_state_on_resolve()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF (OLD.resolved_at IS NULL) AND (NEW.resolved_at IS NOT NULL) THEN
    DELETE FROM public.alert_issue_notify_state
    WHERE device_id = NEW.device_id
      AND issue_key = COALESCE(NEW.type, '');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_alerts_clear_issue_notify_state_on_resolve ON public.alerts;
CREATE TRIGGER trg_alerts_clear_issue_notify_state_on_resolve
  AFTER UPDATE OF resolved_at ON public.alerts
  FOR EACH ROW
  EXECUTE FUNCTION public.clear_alert_issue_notify_state_on_resolve();

