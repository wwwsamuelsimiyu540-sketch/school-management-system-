// Supabase Edge Function: super-admin-create-user
// Creates an Auth account and its matching school-scoped profile.
// Required server secret: SUPABASE_SERVICE_ROLE_KEY. Never expose it to the browser.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return response({ error: "Method not allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL"), serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"), anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !serviceKey || !anonKey) return response({ error: "Server configuration is incomplete." }, 500);
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return response({ error: "Sign in as Super Admin first." }, 401);
  const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const caller = createClient(url, anonKey, { global: { headers: { Authorization: authHeader } }, auth: { autoRefreshToken: false, persistSession: false } });
  const { data: authData, error: authError } = await caller.auth.getUser();
  if (authError || !authData.user) return response({ error: "Your session is invalid. Sign in again." }, 401);
  const { data: actor, error: actorError } = await admin.from("profiles").select("role,school_id").eq("id", authData.user.id).single();
  if (actorError || actor?.role !== "super_admin" || actor.school_id !== null) return response({ error: "Only a platform Super Admin may create accounts." }, 403);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return response({ error: "Invalid JSON request." }, 400); }
  const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
  const fullName = typeof body.full_name === "string" ? body.full_name.trim() : "";
  const password = typeof body.password === "string" ? body.password : "";
  const role = typeof body.role === "string" ? body.role : "";
  const schoolId = typeof body.school_id === "string" && body.school_id ? body.school_id : null;
  const roles = ["principal", "teacher", "bursar", "parent", "student", "super_admin"];
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || fullName.length < 2 || fullName.length > 120 || password.length < 10 || password.length > 128 || !roles.includes(role)) {
    return response({ error: "Check the email, full name, role and temporary password (10–128 characters)." }, 400);
  }
  if (role === "super_admin" && schoolId) return response({ error: "Super Admin accounts must not be assigned to a school." }, 400);
  if (role !== "super_admin" && !schoolId) return response({ error: "Select a school for this account." }, 400);
  if (schoolId) {
    const { data: school, error } = await admin.from("schools").select("id,status").eq("id", schoolId).maybeSingle();
    if (error || !school) return response({ error: "The selected school does not exist." }, 400);
    if (school.status === "suspended") return response({ error: "Cannot assign a new account to a suspended school." }, 400);
  }
  const { data: created, error: createError } = await admin.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { full_name: fullName } });
  if (createError || !created.user) return response({ error: createError?.message || "Could not create Auth account." }, 400);
  const { error: profileError } = await admin.from("profiles").upsert({ id: created.user.id, full_name: fullName, role, school_id: role === "super_admin" ? null : schoolId }, { onConflict: "id" });
  if (profileError) {
    await admin.auth.admin.deleteUser(created.user.id);
    return response({ error: "Could not save the user profile; the new Auth account was rolled back. " + profileError.message }, 500);
  }
  await admin.from("platform_activity_log").insert({ actor_id: authData.user.id, actor_name: authData.user.email || "Super Admin", school_id: null, action: "user_account_created", details: { user_id: created.user.id, role, school_id: role === "super_admin" ? null : schoolId } });
  return response({ success: true, user_id: created.user.id, email, role, school_id: role === "super_admin" ? null : schoolId, message: "User account and profile created." }, 201);
});
