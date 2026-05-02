import { GoogleAuth } from "npm:google-auth-library@9";
import { createClient } from "npm:@supabase/supabase-js@2";

type ReminderType = "weekly" | "monthly";

type ReminderRequest = {
  type?: ReminderType;
  targetRoles?: string[];
  now?: string;
};

type InvoiceRow = {
  id?: unknown;
  no_invoice?: unknown;
  invoice_entity?: unknown;
  tanggal?: unknown;
  tanggal_kop?: unknown;
  nama_pelanggan?: unknown;
  total_bayar?: unknown;
  total_biaya?: unknown;
  pph?: unknown;
  created_at?: unknown;
  armada_start_date?: unknown;
  rincian?: unknown;
  submission_role?: unknown;
  approval_status?: unknown;
};

type ExpenseRow = {
  tanggal?: unknown;
  total_pengeluaran?: unknown;
  keterangan?: unknown;
  note?: unknown;
  rincian?: unknown;
  created_at?: unknown;
};

type DeviceTokenRow = {
  user_id?: unknown;
  token?: unknown;
};

type Summary = {
  cvIncome: number;
  cvExpense: number;
  personalIncome: number;
  personalExpense: number;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const firebaseClientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL") ?? "";
const firebasePrivateKey = (Deno.env.get("FIREBASE_PRIVATE_KEY") ?? "").replace(
  /\\n/g,
  "\n",
);
const cronSecret = Deno.env.get("FINANCE_REMINDER_CRON_SECRET") ?? "";

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function extractBearerToken(authHeader: string | null): string | null {
  const raw = String(authHeader ?? "").trim();
  if (!raw) return null;
  const [scheme, token] = raw.split(" ");
  if (scheme?.toLowerCase() !== "bearer") return null;
  const cleanedToken = String(token ?? "").trim();
  return cleanedToken.length > 0 ? cleanedToken : null;
}

function normalizeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item ?? "").trim().toLowerCase())
    .filter((item) => item.length > 0);
}

function normalizeMarker(value: unknown): string {
  return String(value ?? "")
    .toUpperCase()
    .replaceAll(/[^A-Z0-9.]+/g, "")
    .trim();
}

function toNumber(value: unknown): number {
  if (typeof value === "number") return Number.isFinite(value) ? value : 0;
  let cleaned = String(value ?? "").replaceAll(/[^0-9,.-]/g, "");
  if (!cleaned.trim()) return 0;
  if (cleaned.includes(",")) {
    cleaned = cleaned.replaceAll(".", "").replace(",", ".");
  } else if ((cleaned.match(/\./g) ?? []).length > 1) {
    cleaned = cleaned.replaceAll(".", "");
  }
  const parsed = Number(cleaned);
  return Number.isFinite(parsed) ? parsed : 0;
}

function parseDate(value: unknown): Date | null {
  const raw = String(value ?? "").trim();
  if (!raw) return null;
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) return null;
  return new Date(parsed.getFullYear(), parsed.getMonth(), parsed.getDate());
}

function detailRows(value: unknown): Record<string, unknown>[] {
  if (!value) return [];
  if (Array.isArray(value)) {
    return value
      .filter((row) => row && typeof row === "object")
      .map((row) => row as Record<string, unknown>);
  }
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value);
      return detailRows(parsed);
    } catch (_) {
      return [];
    }
  }
  if (typeof value === "object") return [value as Record<string, unknown>];
  return [];
}

function formatRupiah(value: number): string {
  return `Rp ${Math.round(value).toLocaleString("id-ID")}`;
}

function jakartaParts(source = new Date()): {
  year: number;
  month: number;
  day: number;
} {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Jakarta",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(source);
  const part = (type: string) =>
    Number(parts.find((item) => item.type === type)?.value ?? "0");
  return {
    year: part("year"),
    month: part("month"),
    day: part("day"),
  };
}

function dateOnlyUtc(year: number, month: number, day: number): Date {
  return new Date(Date.UTC(year, month - 1, day));
}

function addDays(date: Date, days: number): Date {
  const next = new Date(date);
  next.setUTCDate(next.getUTCDate() + days);
  return next;
}

function isoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function monthName(month: number): string {
  return [
    "Januari",
    "Februari",
    "Maret",
    "April",
    "Mei",
    "Juni",
    "Juli",
    "Agustus",
    "September",
    "Oktober",
    "November",
    "Desember",
  ][month - 1] ?? "";
}

function resolvePeriod(
  type: ReminderType,
  now = new Date(),
): {
  start: Date;
  endExclusive: Date;
  label: string;
  title: string;
  type: ReminderType;
} {
  const parts = jakartaParts(now);
  const today = dateOnlyUtc(parts.year, parts.month, parts.day);

  if (type === "monthly") {
    const start = dateOnlyUtc(parts.year, parts.month, 1);
    const endExclusive = parts.month === 12
      ? dateOnlyUtc(parts.year + 1, 1, 1)
      : dateOnlyUtc(parts.year, parts.month + 1, 1);
    return {
      start,
      endExclusive,
      label: `Dalam bulan ${monthName(parts.month)} ${parts.year}`,
      title: `Ringkasan Keuangan ${monthName(parts.month)} ${parts.year}`,
      type,
    };
  }

  const weekday = today.getUTCDay() === 0 ? 7 : today.getUTCDay();
  const start = addDays(today, 1 - weekday);
  return {
    start,
    endExclusive: addDays(start, 7),
    label: "Dalam minggu ini",
    title: "Ringkasan Keuangan Mingguan",
    type,
  };
}

function normalizeInvoiceEntity(invoice: InvoiceRow): string {
  const entity = String(invoice.invoice_entity ?? "").trim().toLowerCase();
  if (["cv_ant", "cv.ant", "cv ant", "company"].includes(entity)) {
    return "cv_ant";
  }
  if (["pt_ant", "pt.ant", "pt ant"].includes(entity)) return "pt_ant";
  if (["personal", "pribadi"].includes(entity)) return "personal";

  const number = String(invoice.no_invoice ?? "")
    .toUpperCase()
    .replaceAll(/\s+/g, "");
  if (number.includes("PT.ANT") || number.includes("/PT.ANT/")) {
    return "pt_ant";
  }
  if (number.includes("CV.ANT") || number.includes("/CV.ANT/")) {
    return "cv_ant";
  }
  if (number.includes("/BS/") || number.includes("/ANT/") ||
    number.startsWith("BS")) {
    return "personal";
  }

  const customer = String(invoice.nama_pelanggan ?? "").trim().toUpperCase();
  if (
    customer.startsWith("PT ") || customer.startsWith("PT. ") ||
    customer.startsWith("CV ") || customer.startsWith("CV. ")
  ) {
    return "cv_ant";
  }
  return "personal";
}

function isApprovedForBackoffice(invoice: InvoiceRow): boolean {
  const submission = String(invoice.submission_role ?? "").trim()
    .toLowerCase();
  const approval = String(invoice.approval_status ?? "").trim().toLowerCase();
  return submission !== "pengurus" || approval === "approved";
}

function invoiceTotal(invoice: InvoiceRow): number {
  const totalBayar = toNumber(invoice.total_bayar);
  if (totalBayar > 0) return totalBayar;
  return Math.max(0, toNumber(invoice.total_biaya) - toNumber(invoice.pph));
}

function cvReminderIncome(invoice: InvoiceRow): number {
  const grossTotal = toNumber(invoice.total_biaya);
  if (grossTotal <= 0) return invoiceTotal(invoice);
  return Math.max(0, grossTotal - toNumber(invoice.pph));
}

function invoiceReferenceDate(invoice: InvoiceRow): Date | null {
  for (const row of detailRows(invoice.rincian)) {
    const rowDate = parseDate(row.armada_start_date);
    if (rowDate) return rowDate;
  }
  for (
    const key of ["armada_start_date", "tanggal_kop", "tanggal", "created_at"]
  ) {
    const date = parseDate((invoice as Record<string, unknown>)[key]);
    if (date) return date;
  }
  return null;
}

function expenseTotal(expense: ExpenseRow): number {
  const direct = toNumber(expense.total_pengeluaran);
  if (direct > 0) return direct;
  let sum = 0;
  for (const row of detailRows(expense.rincian)) {
    for (const key of ["jumlah", "total", "nominal", "biaya"]) {
      const parsed = toNumber(row[key]);
      if (parsed > 0) {
        sum += parsed;
        break;
      }
    }
  }
  return sum;
}

function isAutoSanguExpense(expense: ExpenseRow): boolean {
  const note = String(expense.note ?? "").trim().toUpperCase();
  if (note.startsWith("AUTO_SANGU:")) return true;
  const description = String(expense.keterangan ?? "").trim().toLowerCase();
  return description.startsWith("auto sangu sopir -");
}

function autoSanguMarker(expense: ExpenseRow): string {
  const note = String(expense.note ?? "").trim();
  if (note.toUpperCase().startsWith("AUTO_SANGU:")) {
    return note.substring("AUTO_SANGU:".length).trim();
  }
  const description = String(expense.keterangan ?? "").trim();
  const match = /auto\s+sangu\s+sopir\s*-\s*(.+)$/i.exec(description);
  return match?.[1]?.trim() ?? "";
}

function buildSummary(
  invoices: InvoiceRow[],
  expenses: ExpenseRow[],
  start: Date,
  endExclusive: Date,
): Summary {
  const invoiceByMarker = new Map<string, InvoiceRow>();
  for (const invoice of invoices) {
    for (const marker of [invoice.id, invoice.no_invoice]) {
      const key = normalizeMarker(marker);
      if (key) invoiceByMarker.set(key, invoice);
    }
  }

  const summary: Summary = {
    cvIncome: 0,
    cvExpense: 0,
    personalIncome: 0,
    personalExpense: 0,
  };

  for (const invoice of invoices) {
    if (!isApprovedForBackoffice(invoice)) continue;
    const date = invoiceReferenceDate(invoice);
    if (!date || date < start || date >= endExclusive) continue;
    const entity = normalizeInvoiceEntity(invoice);
    if (entity === "cv_ant") summary.cvIncome += cvReminderIncome(invoice);
    if (entity === "personal") summary.personalIncome += invoiceTotal(invoice);
  }

  for (const expense of expenses) {
    if (!isAutoSanguExpense(expense)) continue;
    const date = parseDate(expense.tanggal) ?? parseDate(expense.created_at);
    if (!date || date < start || date >= endExclusive) continue;
    const linkedInvoice = invoiceByMarker.get(
      normalizeMarker(autoSanguMarker(expense)),
    );
    if (!linkedInvoice) continue;
    const entity = normalizeInvoiceEntity(linkedInvoice);
    if (entity === "cv_ant") summary.cvExpense += expenseTotal(expense);
    if (entity === "personal") summary.personalExpense += expenseTotal(expense);
  }

  return summary;
}

function buildReminderBody(label: string, summary: Summary): string {
  return [
    `${label}, pemasukkan CV sebesar: ${formatRupiah(summary.cvIncome)} dengan pengeluaran sebesar: ${formatRupiah(summary.cvExpense)}.`,
    `Pemasukkan pribadi sebesar: ${formatRupiah(summary.personalIncome)} dengan pengeluaran sebesar: ${formatRupiah(summary.personalExpense)}.`,
  ].join("\n");
}

function stringifyData(data: Record<string, unknown>): Record<string, string> {
  const result: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value == null) continue;
    result[key] = typeof value === "string" ? value : JSON.stringify(value);
  }
  return result;
}

async function getGoogleAccessToken(): Promise<string> {
  const auth = new GoogleAuth({
    credentials: {
      project_id: firebaseProjectId,
      client_email: firebaseClientEmail,
      private_key: firebasePrivateKey,
    },
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const client = await auth.getClient();
  const accessToken = await client.getAccessToken();
  if (typeof accessToken?.token === "string" && accessToken.token.length > 0) {
    return accessToken.token;
  }
  throw new Error("Google access token is empty.");
}

async function assertAuthorized(req: Request): Promise<Response | null> {
  const secretHeader = String(req.headers.get("x-cron-secret") ?? "").trim();
  if (cronSecret && secretHeader === cronSecret) return null;

  const bearerToken = extractBearerToken(req.headers.get("Authorization"));
  if (!bearerToken) {
    return jsonResponse(401, { error: "Missing cron secret or bearer token." });
  }

  const callerClient = createClient(supabaseUrl, supabaseAnonKey);
  const { data: claimsData, error: claimsError } = await callerClient.auth
    .getClaims(bearerToken);
  const callerUserId = String(claimsData?.claims?.sub ?? "").trim();
  if (claimsError || !callerUserId) {
    return jsonResponse(401, { error: "Unauthorized caller." });
  }

  const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey);
  const { data: profile, error: profileError } = await serviceClient
    .from("profiles")
    .select("role")
    .eq("id", callerUserId)
    .maybeSingle();
  if (profileError) {
    return jsonResponse(500, {
      error: "Failed to validate caller profile.",
      detail: profileError.message,
    });
  }
  const role = String(profile?.role ?? "").trim().toLowerCase();
  if (!["admin", "owner"].includes(role)) {
    return jsonResponse(403, { error: "Only admin/owner may trigger this." });
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
      return jsonResponse(500, {
        error: "Supabase environment variables are incomplete.",
      });
    }
    if (!firebaseProjectId || !firebaseClientEmail || !firebasePrivateKey) {
      return jsonResponse(500, {
        error: "Firebase push secrets are not configured on the function.",
      });
    }

    const authError = await assertAuthorized(req);
    if (authError) return authError;

    const body = (await req.json().catch(() => ({}))) as ReminderRequest;
    const type: ReminderType = body.type === "monthly" ? "monthly" : "weekly";
    const period = resolvePeriod(type, body.now ? new Date(body.now) : undefined);
    const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey);

    const [invoiceResult, expenseResult] = await Promise.all([
      serviceClient
        .from("invoices")
        .select(
          "id,no_invoice,invoice_entity,tanggal,tanggal_kop,nama_pelanggan,total_bayar,total_biaya,pph,created_at,armada_start_date,rincian,submission_role,approval_status",
        ),
      serviceClient
        .from("expenses")
        .select(
          "tanggal,total_pengeluaran,keterangan,note,rincian,created_at",
        ),
    ]);

    if (invoiceResult.error) {
      return jsonResponse(500, {
        error: "Failed to load invoices.",
        detail: invoiceResult.error.message,
      });
    }
    if (expenseResult.error) {
      return jsonResponse(500, {
        error: "Failed to load expenses.",
        detail: expenseResult.error.message,
      });
    }

    const summary = buildSummary(
      (invoiceResult.data ?? []) as InvoiceRow[],
      (expenseResult.data ?? []) as ExpenseRow[],
      period.start,
      period.endExclusive,
    );
    const title = period.title;
    const message = buildReminderBody(period.label, summary);
    const targetRoles = normalizeStringArray(body.targetRoles);
    const roles = targetRoles.length > 0 ? targetRoles : ["owner", "admin"];

    const { data: profiles, error: profileError } = await serviceClient
      .from("profiles")
      .select("id")
      .in("role", roles);
    if (profileError) {
      return jsonResponse(500, {
        error: "Failed to resolve target roles.",
        detail: profileError.message,
      });
    }

    const userIds = (profiles ?? [])
      .map((row) => String(row.id ?? "").trim())
      .filter((id) => id.length > 0);

    let tokenRows: DeviceTokenRow[] = [];
    if (userIds.length > 0) {
      const { data, error } = await serviceClient
        .from("device_push_tokens")
        .select("user_id, token")
        .in("user_id", userIds)
        .eq("is_active", true);
      if (error) {
        return jsonResponse(500, {
          error: "Failed to load active push tokens.",
          detail: error.message,
        });
      }
      tokenRows = (data ?? []) as DeviceTokenRow[];
    }

    if (tokenRows.length === 0) {
      const { data, error } = await serviceClient
        .from("device_push_tokens")
        .select("user_id, token")
        .in("app_role", roles)
        .eq("is_active", true);
      if (error) {
        return jsonResponse(500, {
          error: "Failed to load active push tokens by role.",
          detail: error.message,
        });
      }
      tokenRows = (data ?? []) as DeviceTokenRow[];
    }

    const targets = Array.from(
      new Map(
        tokenRows
          .map((row) => ({
            userId: String(row.user_id ?? "").trim(),
            token: String(row.token ?? "").trim(),
          }))
          .filter((row) => row.userId && row.token)
          .map((row) => [row.token, row]),
      ).values(),
    );

    if (targets.length === 0) {
      return jsonResponse(200, {
        delivered: 0,
        skipped: true,
        reason: "No active device tokens found.",
        title,
        message,
      });
    }

    const accessToken = await getGoogleAccessToken();
    const invalidTokens: string[] = [];
    const errors: string[] = [];
    let delivered = 0;
    const payload = stringifyData({
      target: "invoice_list",
      notification_type: type === "monthly"
        ? "monthly_finance_summary"
        : "weekly_finance_summary",
      source_type: "scheduled_finance_reminder",
      period_start: isoDate(period.start),
      period_end: isoDate(addDays(period.endExclusive, -1)),
      title,
      body: message,
      notification_title: title,
      notification_body: message,
      sent_at: new Date().toISOString(),
    });
    const messageTag =
      `scheduled_finance:${period.type}:${isoDate(period.start)}`;

    for (const target of targets) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: target.token,
              notification: {
                title,
                body: message,
              },
              data: {
                ...payload,
                badge_count: "1",
                notification_count: "1",
              },
              android: {
                priority: "HIGH",
                ttl: "3600s",
                direct_boot_ok: true,
                notification: {
                  channel_id: "cvant_alerts_v2",
                  icon: "ic_app_notification",
                  sound: "default",
                  tag: messageTag,
                  proxy: "DENY",
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
              },
              apns: {
                headers: {
                  "apns-priority": "10",
                  "apns-push-type": "alert",
                },
                payload: {
                  aps: {
                    alert: {
                      title,
                      body: message,
                    },
                    sound: "default",
                    "content-available": 1,
                    "mutable-content": 1,
                  },
                },
              },
            },
          }),
        },
      );

      if (response.ok) {
        delivered += 1;
        continue;
      }

      const rawError = await response.text();
      errors.push(rawError);
      if (rawError.toLowerCase().includes("unregistered")) {
        invalidTokens.push(target.token);
      }
    }

    if (invalidTokens.length > 0) {
      await serviceClient
        .from("device_push_tokens")
        .update({
          is_active: false,
          updated_at: new Date().toISOString(),
        })
        .in("token", invalidTokens);
    }

    return jsonResponse(200, {
      delivered,
      attempted: targets.length,
      invalidTokens: invalidTokens.length,
      errors,
      title,
      message,
      periodStart: isoDate(period.start),
      periodEnd: isoDate(addDays(period.endExclusive, -1)),
    });
  } catch (error) {
    return jsonResponse(500, {
      error: "Unexpected finance reminder push failure.",
      detail: error instanceof Error ? error.message : String(error),
    });
  }
});
