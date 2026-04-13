import { GoogleAuth } from "npm:google-auth-library@9";
import { createClient } from "npm:@supabase/supabase-js@2";

type PushRequest = {
  userIds?: string[];
  targetRoles?: string[];
  title?: string;
  message?: string;
  data?: Record<string, unknown>;
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

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const firebaseClientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL") ?? "";
const firebasePrivateKey = (Deno.env.get("FIREBASE_PRIVATE_KEY") ?? "").replace(
  /\\n/g,
  "\n",
);

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
    if (!authHeader) {
      return jsonResponse(401, { error: "Missing Authorization header." });
    }

    const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userError,
    } = await callerClient.auth.getUser();

    if (userError || !user) {
      return jsonResponse(401, { error: "Unauthorized caller." });
    }

    const body = (await req.json()) as PushRequest;
    const targetRoles = normalizeStringArray(body.targetRoles).map((role) =>
      role.toLowerCase()
    );
    const requestedUserIds = normalizeStringArray(body.userIds);
    const title = String(body.title ?? "").trim();
    const message = String(body.message ?? "").trim();
    const dataPayload = stringifyData(body.data ?? {});

    if (!title || !message) {
      return jsonResponse(400, { error: "title and message are required." });
    }

    const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey);
    const userIds = new Set<string>(requestedUserIds);

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

    let tokens: string[] = [];

    if (userIds.size > 0) {
      const { data: tokenRows, error: tokenError } = await serviceClient
        .from("device_push_tokens")
        .select("token")
        .in("user_id", Array.from(userIds))
        .eq("is_active", true);

      if (tokenError) {
        return jsonResponse(500, {
          error: "Failed to load active push tokens.",
          detail: tokenError.message,
        });
      }

      tokens = collectTokens(tokenRows ?? []);
    }

    if (tokens.length === 0 && targetRoles.length > 0) {
      const { data: roleTokenRows, error: roleTokenError } = await serviceClient
        .from("device_push_tokens")
        .select("token")
        .in("app_role", targetRoles)
        .eq("is_active", true);

      if (roleTokenError) {
        return jsonResponse(500, {
          error: "Failed to load active push tokens by role.",
          detail: roleTokenError.message,
        });
      }

      tokens = collectTokens(roleTokenRows ?? []);
    }

    if (tokens.length === 0) {
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

    console.log(
      JSON.stringify({
        stage: "sending-push",
        targetRoles,
        resolvedUserIds: Array.from(userIds),
        tokenCount: tokens.length,
        title,
      }),
    );

    for (const token of tokens) {
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
              token,
              notification: {
                title,
                body: message,
              },
              data: dataPayload,
              android: {
                priority: "high",
                notification: {
                  channel_id: "cvant_alerts",
                  sound: "default",
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    "content-available": 1,
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
      const normalized = rawError.toLowerCase();
      if (
        normalized.includes("registration-token-not-registered") ||
        normalized.includes("unregistered")
      ) {
        invalidTokens.push(token);
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
      attempted: tokens.length,
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
