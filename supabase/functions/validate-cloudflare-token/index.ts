import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return respond({ error: "Method not allowed" }, 405);

  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return respond({ error: "Authentication required" }, 401);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } },
  );

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) return respond({ error: "Invalid session" }, 401);

  let body: { token?: string };
  try {
    body = await req.json();
  } catch {
    return respond({ error: "Invalid request body" }, 400);
  }
  const token = body.token?.trim();
  if (!token || token.length > 4096) return respond({ error: "A valid API token is required" }, 400);

  try {
    const response = await fetch("https://api.cloudflare.com/client/v4/user", {
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    });
    const payload = await response.json();
    if (!response.ok || payload.success !== true || !payload.result?.id) {
      return respond({ valid: false, error: "Cloudflare token could not be verified" }, 200);
    }

    const accountsResponse = await fetch("https://api.cloudflare.com/client/v4/accounts?per_page=50", {
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    });
    const accountsPayload = await accountsResponse.json();
    if (!accountsResponse.ok || accountsPayload.success !== true) {
      return respond({ valid: false, error: "Token is valid but account access could not be confirmed" }, 200);
    }

    return respond({
      valid: true,
      cloudflareEmail: payload.result.email ?? null,
      accounts: (accountsPayload.result ?? []).map((account: { id: string; name: string }) => ({
        id: account.id,
        name: account.name,
      })),
    });
  } catch {
    return respond({ error: "Cloudflare verification is temporarily unavailable" }, 502);
  }
});

function respond(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
