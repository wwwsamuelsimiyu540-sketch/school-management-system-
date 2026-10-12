// Supabase Edge Function: super-admin-manage-user
// Auth account status operations are server-side only.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const response=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...corsHeaders,"Content-Type":"application/json"}});
Deno.serve(async(req)=>{
  if(req.method==="OPTIONS")return new Response("ok",{headers:corsHeaders});
  if(req.method!=="POST")return response({error:"Method not allowed"},405);
  const url=Deno.env.get("SUPABASE_URL"),service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),anon=Deno.env.get("SUPABASE_ANON_KEY");
  if(!url||!service||!anon)return response({error:"Server configuration is incomplete."},500);
  const auth=req.headers.get("Authorization");if(!auth)return response({error:"Sign in as Super Admin first."},401);
  const admin=createClient(url,service,{auth:{autoRefreshToken:false,persistSession:false}});
  const caller=createClient(url,anon,{global:{headers:{Authorization:auth}},auth:{autoRefreshToken:false,persistSession:false}});
  const {data:authData,error:authError}=await caller.auth.getUser();if(authError||!authData.user)return response({error:"Session invalid. Sign in again."},401);
  const {data:profile,error:profileError}=await admin.from("profiles").select("role,school_id").eq("id",authData.user.id).single();
  if(profileError||profile?.role!=="super_admin"||profile.school_id!==null)return response({error:"Only a platform Super Admin may manage Auth account status."},403);
  let body:Record<string,unknown>;try{body=await req.json()}catch{return response({error:"Invalid JSON."},400)}
  const action=body.action,userId=typeof body.user_id==="string"?body.user_id:"";
  if(action==="list"){
    const {data,error}=await admin.auth.admin.listUsers({page:1,perPage:1000});
    if(error)return response({error:error.message},500);
    return response({users:(data.users||[]).map(u=>({id:u.id,email:u.email||"",banned_until:u.banned_until||null,last_sign_in_at:u.last_sign_in_at||null,email_confirmed_at:u.email_confirmed_at||null}))});
  }
  if(action==="set_status"){
    if(!userId||!["active","disabled"].includes(String(body.status)))return response({error:"Provide user_id and status active or disabled."},400);
    if(userId===authData.user.id)return response({error:"You cannot disable your own Super Admin session."},400);
    const {data:target,error:targetError}=await admin.from("profiles").select("id,role,school_id").eq("id",userId).maybeSingle();
    if(targetError||!target)return response({error:"Target profile not found."},404);
    if(target.role==="super_admin"&&body.status==="disabled")return response({error:"Super Admin accounts must be disabled through a separate emergency recovery procedure."},403);
    const ban_duration=body.status==="disabled"?"876000h":"none";
    const {data:updated,error:updateError}=await admin.auth.admin.updateUserById(userId,{ban_duration});
    if(updateError)return response({error:updateError.message},400);
    await admin.from("platform_activity_log").insert({actor_id:authData.user.id,actor_name:authData.user.email||"Super Admin",school_id:null,action:body.status==="disabled"?"user_account_disabled":"user_account_enabled",details:{user_id:userId,role:target.role}});
    return response({success:true,user_id:updated.user.id,status:body.status});
  }
  return response({error:"Unsupported action."},400);
});
