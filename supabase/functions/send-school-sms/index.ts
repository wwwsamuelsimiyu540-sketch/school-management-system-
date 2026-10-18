import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.0";
const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
Deno.serve(async (req: Request) => {
 if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
 if (req.method !== "POST") return new Response(JSON.stringify({ error: "POST required" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
 try {
  const url = Deno.env.get("SUPABASE_URL"), anon = Deno.env.get("SUPABASE_ANON_KEY"), apiKey = Deno.env.get("AT_API_KEY"), username = Deno.env.get("AT_USERNAME"), sender = Deno.env.get("AT_SENDER_ID");
  if (!url || !anon) throw new Error("Supabase function environment is incomplete.");
  if (!apiKey || !username) throw new Error("SMS provider is not configured. Add AT_API_KEY and AT_USERNAME secrets before sending.");
  const auth = req.headers.get("Authorization") || "";
  if (!auth.startsWith("Bearer ")) return new Response(JSON.stringify({ error: "Sign-in required." }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  const supabase = createClient(url, anon, { global: { headers: { Authorization: auth } }, auth: { persistSession: false } });
  const { data: userData, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userData.user) return new Response(JSON.stringify({ error: "Invalid session." }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  const { data: profile, error: profileErr } = await supabase.from("profiles").select("id,school_id,role").eq("id", userData.user.id).single();
  if (profileErr || !profile?.school_id || !["administrator", "bursar"].includes(profile.role)) return new Response(JSON.stringify({ error: "Only a school administrator or bursar may send school SMS." }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  const body = await req.json(), id = String(body?.message_id || "");
  if (!id) return new Response(JSON.stringify({ error: "message_id is required." }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  const { data: msg, error: msgErr } = await supabase.from("school_sms_outbox").select("*").eq("id", id).eq("school_id", profile.school_id).eq("status", "queued").single();
  if (msgErr || !msg) return new Response(JSON.stringify({ error: "Queued message not found, already processed, or not accessible." }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  const form = new URLSearchParams({ username, to: msg.recipient_phone, message: msg.message }); if (sender) form.set("from", sender);
  const response = await fetch("https://api.africastalking.com/version1/messaging", { method: "POST", headers: { apiKey, Accept: "application/json", "Content-Type": "application/x-www-form-urlencoded" }, body: form.toString() });
  const responseText = await response.text(); let parsed: any = {}; try { parsed = JSON.parse(responseText); } catch { parsed = { raw: responseText }; }
  const first = parsed?.SMSMessageData?.Recipients?.[0] || {};
  const success = response.ok && (Number(first.statusCode) === 101 || String(first.status || "").toLowerCase() === "success");
  const update = await supabase.from("school_sms_outbox").update({ status: success ? "sent" : "failed", provider_reference: first.messageId || null, provider_response: JSON.stringify(parsed).slice(0, 4000), sent_at: success ? new Date().toISOString() : null }).eq("id", id).eq("school_id", profile.school_id).eq("status", "queued");
  if (update.error) throw new Error("Provider responded but outbox status could not be saved: " + update.error.message);
  return new Response(JSON.stringify({ success, status: success ? "sent" : "failed", provider: "Africa's Talking", detail: parsed }), { status: success ? 200 : 502, headers: { ...corsHeaders, "Content-Type": "application/json" } });
 } catch (e) {
  return new Response(JSON.stringify({ error: e instanceof Error ? e.message : "Unexpected SMS delivery error." }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
 }
});