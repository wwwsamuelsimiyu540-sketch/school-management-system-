// Supabase Edge Function: super_admin-register-school
// Deploy with: supabase functions deploy super_admin-register-school
// Required secret: SUPABASE_SERVICE_ROLE_KEY (set in Supabase, never in browser code).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return response({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !serviceKey || !anonKey) {
    return response({ error: "Server configuration is incomplete." }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return response({ error: "Sign in as Super Admin first." }, 401);

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData.user) return response({ error: "Your session is invalid. Sign in again." }, 401);
  const { data: callerProfile, error: profileError } = await admin
    .from("profiles").select("role,school_id").eq("id", userData.user.id).single();
  if (profileError || callerProfile?.role !== "super_admin" || callerProfile?.school_id !== null) {
    return response({ error: "Only a Super Admin account without a school assignment may register schools." }, 403);
  }

  let input: Record<string, unknown>;
  try { input = await req.json(); } catch { return response({ error: "Invalid JSON request." }, 400); }
  const schoolName = typeof input.school_name === "string" ? input.school_name.trim() : "";
  const schoolCode = typeof input.school_code === "string" ? input.school_code.trim().toUpperCase() : "";
  const county = typeof input.county === "string" ? input.county.trim() : null;
  const curriculum = typeof input.curriculum === "string" ? input.curriculum.trim() : "Kenya CBE (CBC) 2026";
  const schoolLevel = typeof input.school_level === "string" ? input.school_level.trim() : "Comprehensive (PP1–Grade 9)";
  const seniorPathways = Array.isArray(input.senior_pathways) ? input.senior_pathways.filter((v) => typeof v === "string" && ["STEM", "Social Sciences", "Arts and Sports Science"].includes(v)) : [];
  const adminName = typeof input.admin_name === "string" ? input.admin_name.trim() : "";
  const adminEmail = typeof input.admin_email === "string" ? input.admin_email.trim().toLowerCase() : "";
  const adminPassword = typeof input.admin_password === "string" ? input.admin_password : "";
  if (schoolName.length < 2 || schoolName.length > 200 ||
      !/^[A-Z0-9_-]{2,30}$/.test(schoolCode) ||
      adminName.length < 2 || adminName.length > 120 ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(adminEmail) ||
      adminPassword.length < 10 || adminPassword.length > 128) {
    return response({ error: "Check the school details, administrator email, and password (10–128 characters)." }, 400);
  }

  const { data: duplicate, error: duplicateError } = await admin
    .from("schools").select("id").eq("code", schoolCode).maybeSingle();
  if (duplicateError) return response({ error: "Could not validate the school code." }, 500);
  if (duplicate) return response({ error: "That school code is already in use." }, 409);

  const { data: createdUser, error: createUserError } = await admin.auth.admin.createUser({
    email: adminEmail,
    password: adminPassword,
    email_confirm: true,
    user_metadata: { full_name: adminName },
  });
  if (createUserError || !createdUser.user) {
    return response({ error: createUserError?.message || "Could not create administrator account." }, 400);
  }

  const { data: school, error: schoolError } = await admin.from("schools").insert({
    name: schoolName,
    code: schoolCode,
    county: county || null,
    curriculum: curriculum,
    school_level: schoolLevel,
    senior_pathways: seniorPathways,
    status: "approved",
    approved_at: new Date().toISOString(),
    approved_by: userData.user.id,
  }).select("id").single();

  if (schoolError || !school) {
    await admin.auth.admin.deleteUser(createdUser.user.id);
    return response({ error: schoolError?.message || "Could not create school." }, 500);
  }

  // The project's auth trigger may create the profile automatically; upsert handles either case.
  const { error: principalError } = await admin.from("profiles").upsert({
    id: createdUser.user.id,
    full_name: adminName,
    role: "principal",
    school_id: school.id,
  }, { onConflict: "id" });

  if (principalError) {
    await admin.from("schools").delete().eq("id", school.id);
    await admin.auth.admin.deleteUser(createdUser.user.id);
    return response({ error: "The account was created but the school administrator profile could not be set: " + principalError.message }, 500);
  }

  return response({
    success: true,
    school_id: school.id,
    administrator_email: adminEmail,
    message: "School and school administrator created successfully.",
  }, 201);
});
