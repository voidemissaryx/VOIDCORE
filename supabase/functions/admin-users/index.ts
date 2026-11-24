import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return reply({ error: "Authentication required" }, 401);
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceKey) return reply({ error: "Admin service is not configured" }, 500);
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, serviceKey, { auth: { persistSession: false } });
  const { data: { user }, error: authError } = await admin.auth.getUser(authorization.slice(7));
  if (authError || !user) return reply({ error: "Invalid session" }, 401);
  const { data: profile } = await admin.from("profiles").select("role").eq("id", user.id).maybeSingle();
  if (profile?.role !== "admin") return reply({ error: "Administrator access required" }, 403);
  let body: { action?: string; userId?: string; username?: string; email?: string; password?: string };
  try { body = await req.json(); } catch { return reply({ error: "Invalid request body" }, 400); }
  if (body.action === "list") {
    const { data, error } = await admin.auth.admin.listUsers({ page: 1, perPage: 500 });
    if (error) return reply({ error: error.message }, 400);
    const ids = data.users.map((u) => u.id);
    const { data: profiles, error: profileError } = await admin.from("profiles")
      .select("id,username,role,disabled_at,created_at").in("id", ids);
    if (profileError) return reply({ error: profileError.message }, 400);
    const byId = new Map((profiles ?? []).map((p) => [p.id, p]));
    return reply({ users: data.users.map((u) => ({
      id: u.id, email: u.email, username: byId.get(u.id)?.username ?? u.user_metadata?.username ?? "Unknown",
      role: byId.get(u.id)?.role ?? "user", created_at: u.created_at,
      email_confirmed_at: u.email_confirmed_at,
      disabled: Boolean(byId.get(u.id)?.disabled_at) || Boolean(u.banned_until && new Date(u.banned_until) > new Date()),
    })) });
  }
  if (!body.userId || body.userId === user.id) return reply({ error: "Choose another account" }, 400);
  const { data: target, error: targetError } = await admin.auth.admin.getUserById(body.userId);
  if (targetError || !target.user) return reply({ error: "Account not found" }, 404);
  const { data: targetProfile } = await admin.from("profiles").select("role").eq("id", body.userId).maybeSingle();
  if (targetProfile?.role === "admin") return reply({ error: "Administrator accounts are protected" }, 403);
  if (body.action === "disable" || body.action === "enable") {
    const disabled = body.action === "disable";
    const { error } = await admin.auth.admin.updateUserById(body.userId, { ban_duration: disabled ? "876000h" : "none" });
    if (error) return reply({ error: error.message }, 400);
    await admin.from("profiles").update({ disabled_at: disabled ? new Date().toISOString() : null }).eq("id", body.userId);
    return reply({ success: true, disabled });
  }
  if (body.action === "delete") {
    const { error } = await admin.auth.admin.deleteUser(body.userId);
    if (error) return reply({ error: error.message }, 400);
    return reply({ success: true });
  }
  if (body.action === "update") {
    const authUpdates: Record<string, unknown> = {};
    const profileUpdates: Record<string, unknown> = {};
    if (typeof body.email === "string" && body.email.trim()) authUpdates.email = body.email.trim();
    if (typeof body.password === "string" && body.password.length >= 8) authUpdates.password = body.password;
    if (typeof body.username === "string" && /^[A-Za-z0-9_]{3,24}$/.test(body.username.trim())) {
      profileUpdates.username = body.username.trim();
      authUpdates.user_metadata = { ...(target.user.user_metadata ?? {}), username: body.username.trim() };
    }
    if (!Object.keys(authUpdates).length && !Object.keys(profileUpdates).length)
      return reply({ error: "Enter a valid username, email or password change" }, 400);
    if (Object.keys(authUpdates).length) {
      const { error } = await admin.auth.admin.updateUserById(body.userId, authUpdates);
      if (error) return reply({ error: error.message }, 400);
    }
    if (Object.keys(profileUpdates).length) {
      const { error } = await admin.from("profiles").update(profileUpdates).eq("id", body.userId);
      if (error) return reply({ error: error.message }, 400);
    }
    return reply({ success: true, emailConfirmationRequired: Boolean(authUpdates.email) });
  }
  return reply({ error: "Unknown action" }, 400);
});
function reply(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...cors, "Content-Type": "application/json" } });
}
