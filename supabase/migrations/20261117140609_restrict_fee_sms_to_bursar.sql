drop policy if exists "sms_outbox_school_access" on public.school_sms_outbox;
create policy "sms_outbox_school_access" on public.school_sms_outbox
for all to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id=(select auth.uid())
      and p.school_id=school_sms_outbox.school_id
      and p.role in ('administrator','bursar')
      and (p.role='bursar' or school_sms_outbox.message_type <> 'fees')
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id=(select auth.uid())
      and p.school_id=school_sms_outbox.school_id
      and p.role in ('administrator','bursar')
      and (p.role='bursar' or school_sms_outbox.message_type <> 'fees')
  )
);
