/**
 * Alert notifications (email via Resend, SMS via Twilio).
 *
 * 1) Database Webhook on INSERT into public.alerts — body includes `record` (the new row).
 * 2) Backfill / retry — POST JSON: `{ "process_pending": true, "limit": 25 }`
 *    (same Authorization). Picks active alerts where notify_completed_at IS NULL.
 *
 * Env (hosted Supabase injects SUPABASE_* automatically):
 *   NOTIFY_ALERT_SECRET — required; send via header Authorization: Bearer <secret>
 *     or X-Notify-Alert-Secret: <secret> (no "Bearer "). Do not put the secret in the URL query string.
 *   RESEND_API_KEY, RESEND_FROM_EMAIL — email when key is set (domain must be verified in Resend)
 *   TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER — optional SMS
 *
 * Dashboard: Database → Webhooks → INSERT on public.alerts → POST .../functions/v1/notify-alert
 * with header Authorization: Bearer <NOTIFY_ALERT_SECRET>.
 *
 * Optional: schedule repeated POST with `{"process_pending":true}` (e.g. Supabase cron or external)
 * to drain alerts that were created while the webhook or Resend was offline.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

type IssueNotifyState = {
  device_id: string;
  issue_key: string;
  notify_stage: number;
  normal_emailed_at: string | null;
  red_emailed_at: string | null;
};

type WebhookBody = {
  type?: string;
  table?: string;
  record?: Record<string, unknown>;
  /** Backfill mode (boolean or string from some clients / manual tests) */
  process_pending?: boolean | string | number;
  limit?: number;
};

function wantsProcessPending(payload: WebhookBody): boolean {
  const v = payload.process_pending;
  return v === true || v === "true" || v === 1 || v === "1";
}

type NotifyEnv = {
  resendKey?: string;
  resendFrom: string;
  twilioSid?: string;
  twilioToken?: string;
  twilioFrom?: string;
};

type NotifyStats = {
  ownerCount: number;
  anyWantsEmail: boolean;
  anyWantsSms: boolean;
  /** Successful email sends this run */
  emailed: number;
  /** Successful SMS sends this run */
  smsed: number;
  /** Owners we attempted email for (want email + Resend configured + have address) */
  emailTargets: number;
  /** Owners we attempted SMS for */
  smsTargets: number;
  /** Last Resend error body (if any) */
  resendError?: string;
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function twilioConfigured(env: NotifyEnv): boolean {
  return !!(env.twilioSid && env.twilioToken && env.twilioFrom);
}

function issueKeyFromAlertType(alertType: string): string {
  const k = (alertType ?? "").trim();
  return k.length ? k : "alert";
}

async function getOrCreateIssueState(
  admin: SupabaseClient,
  deviceId: string,
  issueKey: string,
  firstAlertId?: string,
): Promise<IssueNotifyState | null> {
  const nowIso = new Date().toISOString();
  const { error: upsertErr } = await admin
    .from("alert_issue_notify_state")
    .upsert(
      {
        device_id: deviceId,
        issue_key: issueKey,
        first_alert_id: firstAlertId ?? null,
        last_alert_at: nowIso,
      },
      { onConflict: "device_id,issue_key" },
    );
  if (upsertErr) {
    console.error("alert_issue_notify_state upsert", upsertErr);
    return null;
  }

  const { data, error } = await admin
    .from("alert_issue_notify_state")
    .select("device_id, issue_key, notify_stage, normal_emailed_at, red_emailed_at")
    .eq("device_id", deviceId)
    .eq("issue_key", issueKey)
    .maybeSingle();
  if (error) {
    console.error("alert_issue_notify_state select", error);
    return null;
  }
  if (!data) return null;
  return data as IssueNotifyState;
}

async function advanceIssueStageAfterSuccess(
  admin: SupabaseClient,
  deviceId: string,
  issueKey: string,
  stage: 1 | 2,
): Promise<void> {
  const patch: Record<string, unknown> = {
    notify_stage: stage,
    last_alert_at: new Date().toISOString(),
  };
  if (stage === 1) patch.normal_emailed_at = new Date().toISOString();
  if (stage === 2) patch.red_emailed_at = new Date().toISOString();

  const { error } = await admin
    .from("alert_issue_notify_state")
    .update(patch)
    .eq("device_id", deviceId)
    .eq("issue_key", issueKey);
  if (error) console.error("alert_issue_notify_state update", error);
}

function shouldCompleteNotification(
  stats: NotifyStats,
  resendKey: string | undefined,
  env: NotifyEnv,
  emailNotified: boolean,
  smsNotified: boolean,
): boolean {
  if (stats.ownerCount === 0) return true;
  if (!stats.anyWantsEmail && !stats.anyWantsSms) return true;
  if (stats.anyWantsEmail && !resendKey) return false;
  if (stats.anyWantsSms && !twilioConfigured(env)) return false;

  const emailDone = !stats.anyWantsEmail || emailNotified;
  const smsDone = !stats.anyWantsSms || smsNotified;
  return emailDone && smsDone;
}

async function sendNotificationsForAlert(
  admin: SupabaseClient,
  deviceId: string,
  message: string,
  severity: string,
  alertType: string,
  env: NotifyEnv,
  existingEmailNotified: boolean,
  existingSmsNotified: boolean,
): Promise<NotifyStats> {
  const { data: owners, error: ownerErr } = await admin
    .from("user_devices")
    .select("user_id")
    .eq("device_id", deviceId);

  if (ownerErr) {
    console.error("user_devices:", ownerErr);
    throw new Error(ownerErr.message);
  }

  const userIds = [...new Set((owners ?? []).map((r) => r.user_id as string))];
  const stats: NotifyStats = {
    ownerCount: userIds.length,
    anyWantsEmail: false,
    anyWantsSms: false,
    emailed: 0,
    smsed: 0,
    emailTargets: 0,
    smsTargets: 0,
  };

  if (userIds.length === 0) return stats;

  const subject = `[PhytoPi] ${alertType} (${severity})`;
  const textBody = `${message}\n\nDevice: ${deviceId}`;

  for (const userId of userIds) {
    const { data: userData, error: userErr } = await admin.auth.admin.getUserById(
      userId,
    );
    if (userErr || !userData?.user?.email) {
      console.error("getUserById", userId, userErr);
      continue;
    }
    const email = userData.user.email;

    const { data: settings } = await admin
      .from("alert_notification_settings")
      .select("email_enabled, sms_enabled, phone_e164")
      .eq("user_id", userId)
      .maybeSingle();

    const emailOn = settings?.email_enabled !== false;
    const smsOn = settings?.sms_enabled === true;
    const phone = (settings?.phone_e164 as string | null) ?? null;

    if (emailOn) stats.anyWantsEmail = true;
    if (smsOn && phone) stats.anyWantsSms = true;

    if (!existingEmailNotified && env.resendKey && emailOn) {
      stats.emailTargets++;
      try {
        const r = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${env.resendKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: env.resendFrom,
            to: [email],
            subject,
            text: textBody,
          }),
        });
        if (r.ok) {
          stats.emailed++;
        } else {
          const errBody = await r.text();
          stats.resendError = `HTTP ${r.status}: ${errBody}`;
          console.error("Resend", stats.resendError);
        }
      } catch (e) {
        console.error("Resend error", e);
      }
    }

    if (
      !existingSmsNotified &&
      twilioConfigured(env) &&
      smsOn &&
      phone
    ) {
      stats.smsTargets++;
      try {
        const authHeader = "Basic " +
          btoa(`${env.twilioSid}:${env.twilioToken}`);
        const params = new URLSearchParams({
          To: phone,
          From: env.twilioFrom!,
          Body: `${subject}: ${message}`.slice(0, 1500),
        });
        const r = await fetch(
          `https://api.twilio.com/2010-04-01/Accounts/${env.twilioSid}/Messages.json`,
          {
            method: "POST",
            headers: {
              Authorization: authHeader,
              "Content-Type": "application/x-www-form-urlencoded",
            },
            body: params.toString(),
          },
        );
        if (r.ok) stats.smsed++;
        else console.error("Twilio", await r.text());
      } catch (e) {
        console.error("Twilio error", e);
      }
    }
  }

  return stats;
}

function emailChannelDone(
  stats: NotifyStats,
  hadEmailNotified: boolean,
): boolean {
  if (hadEmailNotified) return true;
  if (!stats.anyWantsEmail) return true;
  if (stats.emailTargets === 0) return false;
  return stats.emailed === stats.emailTargets;
}

function smsChannelDone(
  stats: NotifyStats,
  hadSmsNotified: boolean,
  env: NotifyEnv,
): boolean {
  if (hadSmsNotified) return true;
  if (!stats.anyWantsSms) return true;
  if (!twilioConfigured(env)) return false;
  if (stats.smsTargets === 0) return false;
  return stats.smsed === stats.smsTargets;
}

async function persistNotifyState(
  admin: SupabaseClient,
  alertId: string,
  stats: NotifyStats,
  env: NotifyEnv,
  hadEmailNotified: boolean,
  hadSmsNotified: boolean,
): Promise<boolean> {
  const nowEmail = emailChannelDone(stats, hadEmailNotified);
  const nowSms = smsChannelDone(stats, hadSmsNotified, env);

  const complete = shouldCompleteNotification(
    stats,
    env.resendKey,
    env,
    nowEmail,
    nowSms,
  );

  const patch: Record<string, string> = {};
  const emailJustFinished =
    !hadEmailNotified &&
    stats.emailTargets > 0 &&
    stats.emailed === stats.emailTargets;
  if (emailJustFinished) {
    patch.email_notified_at = new Date().toISOString();
  }
  const smsJustFinished =
    !hadSmsNotified &&
    stats.smsTargets > 0 &&
    stats.smsed === stats.smsTargets;
  if (smsJustFinished) {
    patch.sms_notified_at = new Date().toISOString();
  }
  if (complete) {
    patch.notify_completed_at = new Date().toISOString();
  }

  if (Object.keys(patch).length === 0) return complete;

  const { error } = await admin.from("alerts").update(patch).eq("id", alertId);
  if (error) console.error("alerts notify update", alertId, error);
  return complete;
}

async function processOneAlert(
  admin: SupabaseClient,
  row: Record<string, unknown>,
  env: NotifyEnv,
): Promise<{ emailed: number; smsed: number; owners: number; completed: boolean; resendError?: string }> {
  const id = row.id as string | undefined;
  const deviceId = row.device_id as string | undefined;
  const message = (row.message as string) ?? "PhytoPi alert";
  const severity = (row.severity as string) ?? "medium";
  const alertType = (row.type as string) ?? "alert";

  if (!id || !deviceId) {
    return { emailed: 0, smsed: 0, owners: 0, completed: false };
  }

  const issueKey = issueKeyFromAlertType(alertType);
  const issueState = await getOrCreateIssueState(admin, deviceId, issueKey, id);
  const stage = issueState?.notify_stage ?? 0;

  // Enforce: 1 normal + 1 red, then suppress until resolved.
  // Suppressed alerts should still be marked notify_completed_at so backfill won't resend.
  const suppressed = stage >= 2;
  const escalated = stage === 1;

  const hadEmail = row.email_notified_at != null;
  const hadSms = row.sms_notified_at != null;

  // If suppressed, skip outbound channels entirely for this alert row.
  if (suppressed) {
    const stats: NotifyStats = {
      ownerCount: 0,
      anyWantsEmail: false,
      anyWantsSms: false,
      emailed: 0,
      smsed: 0,
      emailTargets: 0,
      smsTargets: 0,
    };
    const complete = await persistNotifyState(admin, id, stats, env, hadEmail, hadSms);
    return { emailed: 0, smsed: 0, owners: 0, completed: complete };
  }

  const effectiveSeverity = escalated ? "critical" : severity;
  const effectiveType = escalated ? `RED_${alertType}` : alertType;
  const effectiveMessage = escalated
    ? `RED ALERT (repeat issue):\n${message}`
    : message;

  const stats = await sendNotificationsForAlert(
    admin,
    deviceId,
    effectiveMessage,
    effectiveSeverity,
    effectiveType,
    env,
    hadEmail,
    hadSms,
  );

  // Only advance stage when the email channel actually finished successfully for this run.
  // (We intentionally do not advance on failure so retries can still notify.)
  const emailJustFinished =
    !hadEmail &&
    stats.anyWantsEmail &&
    stats.emailTargets > 0 &&
    stats.emailed === stats.emailTargets;
  if (emailJustFinished) {
    const nextStage: 1 | 2 = escalated ? 2 : 1;
    await advanceIssueStageAfterSuccess(admin, deviceId, issueKey, nextStage);
  }

  const complete = await persistNotifyState(
    admin,
    id,
    stats,
    env,
    hadEmail,
    hadSms,
  );

  return {
    emailed: stats.emailed,
    smsed: stats.smsed,
    owners: stats.ownerCount,
    completed: complete,
    resendError: stats.resendError,
  };
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "method not allowed" }, 405);
  }

  const secret = Deno.env.get("NOTIFY_ALERT_SECRET") ?? "";
  const authHeader = req.headers.get("authorization") ?? "";
  const fromBearer = authHeader.startsWith("Bearer ")
    ? authHeader.slice(7).trim()
    : "";
  const fromCustom = req.headers.get("x-notify-alert-secret")?.trim() ?? "";
  const token = fromBearer || fromCustom;
  if (!secret || token !== secret) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceKey) {
    return jsonResponse({ error: "server misconfigured" }, 500);
  }

  let payload: WebhookBody;
  try {
    payload = (await req.json()) as WebhookBody;
  } catch {
    return jsonResponse({ error: "invalid json" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const env: NotifyEnv = {
    resendKey: Deno.env.get("RESEND_API_KEY") ?? undefined,
    resendFrom: Deno.env.get("RESEND_FROM_EMAIL") ?? "PhytoPi <alerts@example.com>",
    twilioSid: Deno.env.get("TWILIO_ACCOUNT_SID") ?? undefined,
    twilioToken: Deno.env.get("TWILIO_AUTH_TOKEN") ?? undefined,
    twilioFrom: Deno.env.get("TWILIO_FROM_NUMBER") ?? undefined,
  };

  if (wantsProcessPending(payload)) {
    const limit = Math.min(Math.max(Number(payload.limit) || 25, 1), 100);
    const { data: rows, error: qerr } = await admin
      .from("alerts")
      .select("*")
      .is("notify_completed_at", null)
      .is("resolved_at", null)
      .order("triggered_at", { ascending: true })
      .limit(limit);

    if (qerr) {
      console.error("pending query", qerr);
      return jsonResponse({ error: qerr.message }, 500);
    }

    let emailed = 0;
    let smsed = 0;
    let completed = 0;
    const alertDebug: unknown[] = [];
    for (const row of rows ?? []) {
      try {
        const r = await processOneAlert(
          admin,
          row as Record<string, unknown>,
          env,
        );
        emailed += r.emailed;
        smsed += r.smsed;
        if (r.completed) completed++;
        alertDebug.push({
          id: (row as Record<string, unknown>).id,
          emailed: r.emailed,
          owners: r.owners,
          completed: r.completed,
          resend_error: r.resendError ?? null,
        });
      } catch (e) {
        console.error("process alert", row, e);
        alertDebug.push({
          id: (row as Record<string, unknown>).id,
          error: String(e),
        });
      }
    }

    return jsonResponse({
      ok: true,
      mode: "process_pending",
      scanned: (rows ?? []).length,
      emailed,
      smsed,
      completed,
      config: {
        resend_configured: !!env.resendKey,
        twilio_configured: twilioConfigured(env),
        resend_from_set: env.resendFrom !==
          "PhytoPi <alerts@example.com>",
        resend_from: env.resendFrom,
      },
      debug: alertDebug,
    });
  }

  const record = payload.record;
  if (!record || typeof record !== "object") {
    return jsonResponse({
      ok: true,
      skipped: "no record",
      hint:
        "Database webhooks send { record: {...} }. To drain unsent alerts, POST JSON with process_pending: true (redeploy this function if you only get this hint).",
    });
  }

  const deviceId = record.device_id as string | undefined;
  if (!deviceId) {
    return jsonResponse({ ok: true, skipped: "no device_id" });
  }

  try {
    const r = await processOneAlert(admin, record, env);
    return jsonResponse({
      ok: true,
      emailed: r.emailed,
      smsed: r.smsed,
      owners: r.owners,
      notify_completed: r.completed,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonResponse({ error: msg }, 500);
  }
});
