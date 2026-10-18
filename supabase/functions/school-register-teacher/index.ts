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
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !serviceKey || !anonKey) return response({ error: "Server configuration is incomplete." }, 500);
  const authorization = req.headers.get("Authorization");
  if (!authorization) return response({ error: "Sign in as a school administrator first." }, 401);
  const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const caller = createClient(url, anonKey, { global: { headers: { Authorization: authorization } }, auth: { autoRefreshToken: false, persistSession: false } });
  const { data: authData, error: authError } = await caller.auth.getUser();
  if (authError || !authData.user) return response({ error: "Your session is invalid. Sign in again." }, 401);
  const { data: actor, error: actorError } = await admin.from("profiles").select("role,school_id").eq("id", authData.user.id).single();
  if (actorError || !actor || actor.role !== "administrator" || !actor.school_id) {
    return response({ error: "Only a school administrator can register teachers for their own school." }, 403);
  }
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return response({ error: "Invalid JSON request." }, 400); }
  const fullName = typeof body.full_name === "string" ? body.full_name.trim() : "";
  const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
  const password = typeof body.password === "string" ? body.password : "";
  const staffNo = typeof body.staff_no === "string" ? body.staff_no.trim() : "";
  const tscNo = typeof body.tsc_no === "string" ? body.tsc_no.trim() : "";
  const phone = typeof body.phone === "string" ? body.phone.trim() : "";
  const gender = typeof body.gender === "string" ? body.gender.trim() : "";
  const grade = typeof body.grade === "string" ? body.grade.trim() : "";
  const stream = typeof body.stream === "string" ? body.stream.trim() : "";
  const subjectIds = Array.isArray(body.subject_ids) ? [...new Set(body.subject_ids.filter((v): v is string => typeof v === "string" && v.length > 0))] : (typeof body.subject_id === "string" && body.subject_id ? [body.subject_id] : []);
  if (fullName.length < 2 || fullName.length > 120 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || password.length < 10 || password.length > 128 || !staffNo || staffNo.length > 40 || !grade || !stream || subjectIds.length < 2 || subjectIds.length > 30) {
    return response({ error: "Enter the teacher's name, valid email, temporary password (at least 10 characters), staff number, grade, stream and at least two distinct subjects." }, 400);
  }
  if (gender && !["Female", "Male", "Prefer not to say"].includes(gender)) return response({ error: "Choose a valid gender option." }, 400);
  const { data: school, error: schoolError } = await admin.from("schools").select("id,status,school_level").eq("id", actor.school_id).maybeSingle();
  if (schoolError || !school || school.status !== "approved") return response({ error: "Your school must be approved before teacher accounts can be registered." }, 403);
  const expectedLevel = grade === "PP1" || grade === "PP2" ? "Pre-Primary" : /^Grade [1-6]$/.test(grade) ? "Primary" : /^Grade [7-9]$/.test(grade) ? "Junior School" : /^Grade (10|11|12)$/.test(grade) ? "Senior School" : null;
  if (!expectedLevel || !Array.isArray(school.school_level) || !school.school_level.includes(expectedLevel)) return response({ error: "The selected grade is outside the education levels registered for this school." }, 400);
  const { data: classRow, error: classError } = await admin.from("school_classes").select("id").eq("school_id", actor.school_id).eq("grade", grade).eq("stream", stream).maybeSingle();
  if (classError || !classRow) return response({ error: "That stream is not registered for the selected grade. Create the class and stream first." }, 400);
  const { data: subjects, error: subjectsError } = await admin.from("subjects").select("id,grade,education_level,pathway,track").eq("school_id", actor.school_id).in("id", subjectIds);
  if (subjectsError || !subjects || subjects.length !== subjectIds.length || subjects.some((subject) => subject.grade !== grade || subject.education_level !== expectedLevel || (expectedLevel === "Senior School" && (!subject.pathway || !subject.track)))) return response({ error: "Choose only subjects registered for this grade and education level in your school. Senior School subjects must include a pathway and track." }, 400);
  const { data: existingStaff } = await admin.from("profiles").select("id").eq("school_id", actor.school_id).eq("staff_no", staffNo).maybeSingle();
  if (existingStaff) return response({ error: "That staff number is already registered in this school." }, 409);
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email, password, email_confirm: true, user_metadata: { full_name: fullName }
  });
  if (createError || !created.user) return response({ error: createError?.message || "Could not create the teacher login." }, 400);
  const { error: profileError } = await admin.from("profiles").upsert({
    id: created.user.id, school_id: actor.school_id, full_name: fullName, role: "teacher",
    phone: phone || null, staff_no: staffNo, tsc_no: tscNo || null, gender: gender || null
  }, { onConflict: "id" });
  if (profileError) {
    await admin.auth.admin.deleteUser(created.user.id);
    return response({ error: "Could not save the teacher profile; login creation was rolled back. " + profileError.message }, 500);
  }
  const assignmentRows = subjectIds.map((subject_id) => ({ school_id: actor.school_id, teacher_id: created.user.id, grade, stream, subject_id }));
  const { error: assignmentError } = await admin.from("teacher_assignments").insert(assignmentRows);
  if (assignmentError) {
    await admin.from("profiles").delete().eq("id", created.user.id);
    await admin.auth.admin.deleteUser(created.user.id);
    return response({ error: "Could not save the class, stream and subject assignment; teacher creation was rolled back. " + assignmentError.message }, 500);
  }
  await admin.from("platform_activity_log").insert({
    actor_id: authData.user.id, school_id: actor.school_id, action: "teacher_registered",
    details: { teacher_id: created.user.id, staff_no: staffNo, grade, stream, subject_ids: subjectIds }
  });
  return response({ success: true, teacher_id: created.user.id, message: "Teacher account registered and all selected subject assignments saved." }, 201);
});