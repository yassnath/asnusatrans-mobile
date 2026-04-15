import { GoogleAuth } from "npm:google-auth-library@9";
import { createClient } from "npm:@supabase/supabase-js@2";

type PushRequest = {
  userIds?: string[];
  targetRoles?: string[];
  title?: string;
  message?: string;
  data?: Record<string, unknown>;
};

type DeviceTokenRow = {
  user_id?: unknown;
  token?: unknown;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function normalizeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item ?? "").trim())
    .filter((item) => item.length > 0);
}

function stringifyData(data: Record<string, unknown>): Record<string, string> {
  const result: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value == null) continue;
    result[key] = typeof value === "string" ? value : JSON.stringify(value);
  }
  return result;
}

function collectTokens(rows: Array<{ token?: unknown }>): string[] {
  return Array.from(
    new Set(
      rows
        .map((row) => String(row.token ?? "").trim())
        .filter((token) => token.length > 0),
    ),
  );
}

function collectDeviceTargets(rows: DeviceTokenRow[]): Array<{
  userId: string;
  token: string;
}> {
  const targets = new Map<string, { userId: string; token: string }>();
  for (const row of rows) {
    const token = String(row.token ?? "").trim();
    const userId = String(row.user_id ?? "").trim();
    if (!token || !userId) continue;
    targets.set(token, { userId, token });
  }
  return Array.from(targets.values());
}

function collectRoleTopics(roles: string[]): string[] {
  return Array.from(
    new Set(
      roles
        .map((role) => role.trim().toLowerCase())
        .filter((role) =>
          ["admin", "owner", "pengurus", "customer"].includes(role)
        )
        .map((role) => `role_${role}`),
    ),
  );
}

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const firebaseClientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL") ?? "";
const firebasePrivateKey = (Deno.env.get("FIREBASE_PRIVATE_KEY") ?? "").replace(
  /\\n/g,
  "\n",
);

function extractBearerToken(authHeader: string | null): string | null {
  const raw = String(authHeader ?? "").trim();
  if (!raw) return null;
  const [scheme, token] = raw.split(" ");
  if (scheme?.toLowerCase() !== "bearer") return null;
  const cleanedToken = String(token ?? "").trim();
  return cleanedToken.length > 0 ? cleanedToken : null;
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
  if (!accessToken) {
    throw new Error("Failed to resolve Google access token.");
  }
  if (typeof accessToken === "string") return accessToken;
  if (typeof accessToken.token === "string" && accessToken.token.length > 0) {
    return accessToken.token;
  }
  throw new Error("Google access token is empty.");
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

    const authHeader = req.headers.get("Authorization");
    const bearerToken = extractBearerToken(authHeader);
    if (!bearerToken) {
      return jsonResponse(401, { error: "Missing Authorization header." });
    }

    const callerClient = createClient(supabaseUrl, supabaseAnonKey);
    const { data: claimsData, error: claimsError } = await callerClient.auth
      .getClaims(bearerToken);
    const callerUserId = String(claimsData?.claims?.sub ?? "").trim();
    if (claimsError || !callerUserId) {
      return jsonResponse(401, { error: "Unauthorized caller." });
    }

    const body = (await req.json()) as PushRequest;
    const targetRoles = normalizeStringArray(body.targetRoles).map((role) =>
      role.toLowerCase()
    );
    const requestedUserIds = normalizeStringArray(body.userIds);
    const title = String(body.title ?? "").trim();
    const message = String(body.message ?? "").trim();
    const dataPayload = stringifyData({
      ...(body.data ?? {}),
      title,
      body: message,
      notification_title: title,
      notification_body: message,
      sent_at: new Date().toISOString(),
    });

    if (!title || !message) {
      return jsonResponse(400, { error: "title and message are required." });
    }

    const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey);
    const userIds = new Set<string>(requestedUserIds);
    const roleTopics = collectRoleTopics(targetRoles);

    if (targetRoles.length > 0) {
      const { data: profiles, error: profileError } = await serviceClient
        .from("profiles")
        .select("id")
        .in("role", targetRoles);
      if (profileError) {
        return jsonResponse(500, {
          error: "Failed to resolve target roles.",
          detail: profileError.message,
        });
      }
      for (const row of profiles ?? []) {
        const id = String(row.id ?? "").trim();
        if (id) userIds.add(id);
      }
    }

    if (userIds.size == 0) {
      console.log(
        JSON.stringify({
          stage: "resolve-target-users",
          targetRoles,
          requestedUserIds,
          reason: "No target users resolved from profiles lookup.",
        }),
      );
    }

    let deviceTargets: Array<{ userId: string; token: string }> = [];

    if (userIds.size > 0) {
      const { data: tokenRows, error: tokenError } = await serviceClient
        .from("device_push_tokens")
        .select("user_id, token")
        .in("user_id", Array.from(userIds))
        .eq("is_active", true);

      if (tokenError) {
        return jsonResponse(500, {
          error: "Failed to load active push tokens.",
          detail: tokenError.message,
        });
      }

      deviceTargets = collectDeviceTargets((tokenRows ?? []) as DeviceTokenRow[]);
    }

    if (deviceTargets.length === 0 && targetRoles.length > 0) {
      const { data: roleTokenRows, error: roleTokenError } = await serviceClient
        .from("device_push_tokens")
        .select("user_id, token")
        .in("app_role", targetRoles)
        .eq("is_active", true);

      if (roleTokenError) {
        return jsonResponse(500, {
          error: "Failed to load active push tokens by role.",
          detail: roleTokenError.message,
        });
      }

      deviceTargets = collectDeviceTargets(
        (roleTokenRows ?? []) as DeviceTokenRow[],
      );
    }

    if (deviceTargets.length === 0) {
      console.log(
        JSON.stringify({
          stage: "resolve-device-tokens",
          targetRoles,
          resolvedUserIds: Array.from(userIds),
          reason: "No active device tokens found.",
        }),
      );
      return jsonResponse(200, {
        delivered: 0,
        skipped: true,
        reason: "No active device tokens found.",
      });
    }

    const accessToken = await getGoogleAccessToken();

    let delivered = 0;
    const invalidTokens: string[] = [];
    const errors: string[] = [];
    const unreadCountByUser = new Map<string, number>();
    const requestType = dataPayload["request_type"] ?? "";
    const sourceType = dataPayload["source_type"] ?? "push";
    const sourceId = dataPayload["source_id"] ?? dataPayload["invoice_id"] ?? "";
    const messageTag = [sourceType, requestType, sourceId]
      .map((part) => String(part ?? "").trim())
      .filter((part) => part.length > 0)
      .join(":") || `push:${Date.now()}`;

    const targetUserIds = Array.from(
      new Set(deviceTargets.map((target) => target.userId).filter((id) => id)),
    );
    if (targetUserIds.length > 0) {
      const { data: unreadRows, error: unreadError } = await serviceClient
        .from("customer_notifications")
        .select("user_id")
        .in("user_id", targetUserIds)
        .eq("status", "unread");

      if (unreadError) {
        console.log(
          JSON.stringify({
            stage: "resolve-unread-counts",
            detail: unreadError.message,
          }),
        );
      } else {
        for (const row of unreadRows ?? []) {
          const userId = String(row.user_id ?? "").trim();
          if (!userId) continue;
          unreadCountByUser.set(userId, (unreadCountByUser.get(userId) ?? 0) + 1);
        }
      }
    }

    console.log(
      JSON.stringify({
        stage: "sending-push",
        targetRoles,
        resolvedUserIds: Array.from(userIds),
        tokenCount: deviceTargets.length,
        topicCount: roleTopics.length,
        title,
      }),
    );

    const sendMessage = async (
      target:
        | { token: string; userId?: string; badgeCount?: number }
        | { topic: string; badgeCount?: number },
    ) => {
      const badgeCount = Math.max(1, target.badgeCount ?? 1);
      const fcmTarget =
        "token" in target
          ? { token: target.token }
          : { topic: target.topic };
      const messageData = {
        ...dataPayload,
        badge_count: String(badgeCount),
        notification_count: String(badgeCount),
      };
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
              ...fcmTarget,
              notification: {
                title,
                body: message,
              },
              data: messageData,
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
        return;
      }

      const rawError = await response.text();
      errors.push(rawError);
      console.log(
        JSON.stringify({
          stage: "fcm-send-failed",
          targetType: "token" in target ? "token" : "topic",
          targetValue: "token" in target ? target.token : target.topic,
          detail: rawError,
        }),
      );
      if ("token" in target) {
        const normalized = rawError.toLowerCase();
        if (
          normalized.includes("registration-token-not-registered") ||
          normalized.includes("unregistered")
        ) {
          invalidTokens.push(target.token);
        }
      }
    };

    for (const target of deviceTargets) {
      const badgeCount = unreadCountByUser.get(target.userId) ?? 1;
      await sendMessage({
        token: target.token,
        userId: target.userId,
        badgeCount,
      });
    }

    if (deviceTargets.length === 0) {
      for (const topic of roleTopics) {
        const badgeCount = Math.max(...unreadCountByUser.values(), 1);
        await sendMessage({ topic, badgeCount });
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
      attempted: deviceTargets.length + roleTopics.length,
      invalidTokens: invalidTokens.length,
      errors,
    });
  } catch (error) {
    return jsonResponse(500, {
      error: "Unexpected send-push failure.",
      detail: error instanceof Error ? error.message : String(error),
    });
  }
});
