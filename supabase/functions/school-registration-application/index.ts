import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}
function clean(value: unknown, max = 250): string {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return reply({ error: "Method not allowed." }, 405);
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return reply({ error: "Server configuration is incomplete." }, 500);
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply({ error: "Invalid request." }, 400); }
  if (clean(body.website, 200)) return reply({ success: true, message: "Application received." });
  const schoolName = clean(body.school_name, 200);
  const schoolType = clean(body.school_type, 80);
  const county = clean(body.county, 100);
  const town = clean(body.town, 120);
  const physicalAddress = clean(body.physical_address, 250);
  const schoolPhone = clean(body.school_phone, 40);
  const schoolEmail = clean(body.school_email, 254).toLowerCase();
  const curriculum = clean(body.curriculum, 100) || "Kenya CBE (CBC) 2026";
  const schoolLevel = clean(body.school_level, 100) || "Comprehensive (PP1–Grade 9)";
  const administratorName = clean(body.administrator_name, 120);
  const administratorEmail = clean(body.administrator_email, 254).toLowerCase();
  const administratorPhone = clean(body.administrator_phone, 40);
  const password = typeof body.administrator_password === "string" ? body.administrator_password : "";
  const notes = clean(body.registration_notes, 1500);
  const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (schoolName.length < 2 || administratorName.length < 2 || !emailPattern.test(administratorEmail) || password.length < 10 || password.length > 128) {
    return reply({ error: "Enter the school name, administrator name, a valid administrator email, and a password of 10–128 characters." }, 400);
  }
  if (schoolEmail && !emailPattern.test(schoolEmail)) return reply({ error: "Enter a valid school email address." }, 400);
  if (!["Day", "Boarding", "Mixed day and boarding"].includes(schoolType)) return reply({ error: "Choose a valid school type." }, 400);
  const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data: sameName, error: nameError } = await admin.from("schools").select("id").ilike("name", schoolName).limit(1);
  if (nameError) return reply({ error: "Could not validate the school application. Please try again." }, 500);
  if (sameName?.length) return reply({ error: "A school with this name is already registered. Contact support if this is a duplicate application." }, 409);
  const { data: createdUser, error: userError } = await admin.auth.admin.createUser({
    email: administratorEmail, password, email_confirm: true, user_metadata: { full_name: administratorName },
  });
  if (userError || !createdUser.user) {
    const message = userError?.message || "Could not create the administrator login.";
    if (/already|registered|exists/i.test(message)) return reply({ error: "This administrator email already has an account. Sign in or contact support before registering another school." }, 409);
    return reply({ error: message }, 400);
  }
  // schools.code is NOT NULL and has no database default, so generate a unique code here.
  const schoolCode = "SCH-" + crypto.randomUUID().replaceAll("-", "").slice(0, 8).toUpperCase();
  const { data: school, error: schoolError } = await admin.from("schools").insert({
    name: schoolName, code: schoolCode, county: county || null, school_type: schoolType,
    town: town || null, physical_address: physicalAddress || null, school_phone: schoolPhone || null,
    school_email: schoolEmail || null, administrator_name: administratorName, administrator_email: administratorEmail,
    administrator_phone: administratorPhone || null, curriculum, school_level: schoolLevel,
    registration_notes: notes || null, status: "pending", senior_pathways: [],
  }).select("id,code").single();
  if (schoolError || !school) {
    await admin.auth.admin.deleteUser(createdUser.user.id);
    if (schoolError?.code === "23505") return reply({ error: "A duplicate school code was generated. Please submit again." }, 409);
    return reply({ error: schoolError?.message || "Could not save the school application." }, 500);
  }
  const { error: profileError } = await admin.from("profiles").upsert({
    id: createdUser.user.id, full_name: administratorName, role: "principal", school_id: school.id,
  }, { onConflict: "id" });
  if (profileError) {
    await admin.from("schools").delete().eq("id", school.id);
    await admin.auth.admin.deleteUser(createdUser.user.id);
    return reply({ error: "The application could not finish setting up the administrator account. Please try again." }, 500);
  }
  return reply({ success: true, school_id: school.id, school_code: school.code, administrator_email: administratorEmail,
    status: "pending", message: "Application received. Your school must be approved by the developer before you can sign in." }, 201);
});