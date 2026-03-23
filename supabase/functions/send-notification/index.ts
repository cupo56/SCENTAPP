import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// =========================================================
// Types
// =========================================================

interface NotificationPayload {
  type: "new_review" | "review_like";
  targetUserId: string;
  perfumeId?: string;
  reviewId?: string;
  actorName?: string;
  perfumeName?: string;
}

// =========================================================
// Handler
// =========================================================

Deno.serve(async (req) => {
  // Nur interne Aufrufe (Trigger) erlauben
  const authHeader = req.headers.get("Authorization");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (authHeader !== `Bearer ${serviceRoleKey}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  const payload: NotificationPayload = await req.json();

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    serviceRoleKey!,
  );

  // Präferenz prüfen
  const prefColumn = payload.type === "new_review" ? "new_reviews" : "review_likes";
  const { data: prefs } = await supabase
    .from("notification_preferences")
    .select(prefColumn)
    .eq("user_id", payload.targetUserId)
    .single();

  if (prefs && prefs[prefColumn] === false) {
    return new Response(JSON.stringify({ skipped: "preference_disabled" }), { status: 200 });
  }

  // Device-Tokens laden
  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("user_id", payload.targetUserId)
    .eq("platform", "ios");

  if (!tokens || tokens.length === 0) {
    return new Response(JSON.stringify({ skipped: "no_tokens" }), { status: 200 });
  }

  // Benachrichtigungsinhalt
  const { title, body } = buildContent(payload);
  const deepLink = `scentboxd://perfume/${payload.perfumeId ?? ""}`;

  // APNs-Nachrichten senden
  const results = await Promise.allSettled(
    tokens.map((t: { token: string }) =>
      sendAPNs(t.token, title, body, deepLink),
    ),
  );

  const sent = results.filter((r) => r.status === "fulfilled").length;
  const failed = results.length - sent;

  return new Response(JSON.stringify({ sent, failed }), { status: 200 });
});

// =========================================================
// Content Builder
// =========================================================

function buildContent(payload: NotificationPayload): { title: string; body: string } {
  const actor = payload.actorName ?? "Jemand";
  const perfume = payload.perfumeName ?? "einem Parfum";

  switch (payload.type) {
    case "new_review":
      return {
        title: "Neue Bewertung",
        body: `${actor} hat ${perfume} bewertet`,
      };
    case "review_like":
      return {
        title: "Jemand mag deine Bewertung",
        body: `${actor} hat deine Bewertung von ${perfume} geliked`,
      };
  }
}

// =========================================================
// APNs
// Benötigt folgende Supabase Edge Function Secrets:
//   APNS_TEAM_ID      – Apple Developer Team ID (10 Zeichen)
//   APNS_KEY_ID       – APNs Auth Key ID (10 Zeichen)
//   APNS_PRIVATE_KEY  – Inhalt der .p8-Datei (PEM-Format)
//   APNS_BUNDLE_ID    – Bundle Identifier der App (z.B. com.yourname.scentboxd)
//   APNS_PRODUCTION   – "true" für Produktion, sonst Sandbox
// =========================================================

async function sendAPNs(
  deviceToken: string,
  title: string,
  body: string,
  deepLink: string,
): Promise<void> {
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const privateKey = Deno.env.get("APNS_PRIVATE_KEY")!;
  const bundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "com.yourname.scentboxd";
  const isProduction = Deno.env.get("APNS_PRODUCTION") === "true";

  const apnsHost = isProduction
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";

  const jwtToken = await generateAPNsJWT(teamId, keyId, privateKey);

  const apnsPayload = {
    aps: {
      alert: { title, body },
      sound: "default",
      badge: 1,
    },
    deepLink,
  };

  const response = await fetch(`${apnsHost}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${jwtToken}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(apnsPayload),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`APNs ${response.status}: ${errorBody}`);
  }
}

// =========================================================
// APNs JWT (ES256)
// =========================================================

async function generateAPNsJWT(
  teamId: string,
  keyId: string,
  privateKeyPEM: string,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header = btoa(JSON.stringify({ alg: "ES256", kid: keyId }))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const claims = btoa(JSON.stringify({ iss: teamId, iat: now }))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const signingInput = `${header}.${claims}`;

  const pem = privateKeyPEM
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");

  const binaryKey = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );

  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  return `${signingInput}.${sig}`;
}
