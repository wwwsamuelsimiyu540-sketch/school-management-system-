-- Added by school-management-system feature update.
-- Migration 1: timetable, inventory, learning assignments, submissions and messages.
create table if not exists public.school_timetable_entries (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 grade text not null, stream text not null, learning_area text not null, teacher_id uuid references public.profiles(id) on delete set null,
 room text, day_of_week text not null check(day_of_week in ('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday')),
 start_time time not null, end_time time not null, academic_year integer not null, term text not null,
 created_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now(),
 constraint timetable_time_valid check(end_time > start_time)
);
create table if not exists public.school_inventory_items (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 item_name text not null, category text not null default 'General', unit text not null default 'pieces',
 quantity numeric(12,2) not null default 0 check(quantity >= 0), reorder_level numeric(12,2) not null default 0 check(reorder_level >= 0),
 unit_cost numeric(12,2) not null default 0 check(unit_cost >= 0), supplier text, storage_location text, notes text,
 created_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.school_inventory_transactions (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 item_id uuid not null references public.school_inventory_items(id) on delete cascade,
 transaction_type text not null check(transaction_type in ('received','issued','adjustment')),
 quantity numeric(12,2) not null check(quantity > 0), reason text, reference text,
 recorded_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.school_learning_assignments (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 title text not null, instructions text, learning_area text, grade text not null, stream text,
 teacher_id uuid not null references public.profiles(id) on delete cascade, due_date date,
 attachment_url text, status text not null default 'published' check(status in ('draft','published','closed')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.school_learning_submissions (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 assignment_id uuid not null references public.school_learning_assignments(id) on delete cascade,
 student_id uuid not null references public.students(id) on delete cascade,
 submission_text text, attachment_url text, submitted_at timestamptz not null default now(),
 teacher_feedback text, score numeric(6,2), reviewed_by uuid references public.profiles(id) on delete set null,
 reviewed_at timestamptz, unique(assignment_id,student_id)
);
create table if not exists public.school_messages (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade, recipient_id uuid references public.profiles(id) on delete cascade,
 subject text not null, body text not null, message_type text not null default 'message' check(message_type in ('message','announcement','support')),
 read_at timestamptz, created_at timestamptz not null default now()
);
create index if not exists school_timetable_lookup_idx on public.school_timetable_entries(school_id,academic_year,term,grade,stream,day_of_week,start_time);
create index if not exists school_inventory_low_stock_idx on public.school_inventory_items(school_id,quantity,reorder_level);
create index if not exists school_inventory_transactions_item_idx on public.school_inventory_transactions(school_id,item_id,created_at desc);
create index if not exists school_learning_assignments_class_idx on public.school_learning_assignments(school_id,grade,stream,due_date);
create index if not exists school_learning_submissions_student_idx on public.school_learning_submissions(school_id,student_id,submitted_at desc);
create index if not exists school_messages_inbox_idx on public.school_messages(school_id,recipient_id,created_at desc);
alter table public.school_timetable_entries enable row level security;
alter table public.school_inventory_items enable row level security;
alter table public.school_inventory_transactions enable row level security;
alter table public.school_learning_assignments enable row level security;
alter table public.school_learning_submissions enable row level security;
alter table public.school_messages enable row level security;
create policy timetable_read_school on public.school_timetable_entries for select to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_timetable_entries.school_id));
create policy timetable_admin_write on public.school_timetable_entries for all to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_timetable_entries.school_id and p.role='administrator')) with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_timetable_entries.school_id and p.role='administrator'));
create policy inventory_read_school on public.school_inventory_items for select to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_inventory_items.school_id and p.role in ('administrator','bursar')));
create policy inventory_admin_write on public.school_inventory_items for all to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_inventory_items.school_id and p.role in ('administrator','bursar'))) with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_inventory_items.school_id and p.role in ('administrator','bursar')));
create policy inventory_tx_read_school on public.school_inventory_transactions for select to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_inventory_transactions.school_id and p.role in ('administrator','bursar')));
create policy inventory_tx_write_school on public.school_inventory_transactions for insert to authenticated with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_inventory_transactions.school_id and p.role in ('administrator','bursar')));
create policy learning_assignments_read_school on public.school_learning_assignments for select to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_assignments.school_id and (p.role='administrator' or (p.role='teacher' and (p.id=school_learning_assignments.teacher_id or exists(select 1 from public.teacher_assignments ta where ta.school_id=p.school_id and ta.teacher_id=p.id and ta.grade=school_learning_assignments.grade and (school_learning_assignments.stream is null or ta.stream=school_learning_assignments.stream)))) or exists(select 1 from public.student_account_links l join public.students st on st.id=l.student_id and st.school_id=l.school_id where l.school_id=school_learning_assignments.school_id and l.user_id=p.id and l.active and st.grade=school_learning_assignments.grade and (school_learning_assignments.stream is null or st.stream=school_learning_assignments.stream))));
create policy learning_assignments_write_school on public.school_learning_assignments for all to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_assignments.school_id and (p.role='administrator' or (p.role='teacher' and p.id=school_learning_assignments.teacher_id)))) with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_assignments.school_id and (p.role='administrator' or (p.role='teacher' and p.id=school_learning_assignments.teacher_id))));
create policy learning_submissions_read_school on public.school_learning_submissions for select to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_submissions.school_id and (p.role in ('administrator','teacher') or exists(select 1 from public.student_account_links l where l.school_id=school_learning_submissions.school_id and l.student_id=school_learning_submissions.student_id and l.user_id=p.id and l.active))));
create policy learning_submissions_write_school on public.school_learning_submissions for all to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_submissions.school_id and (p.role='administrator' or (p.role='student' and exists(select 1 from public.student_account_links l where l.school_id=school_learning_submissions.school_id and l.student_id=school_learning_submissions.student_id and l.user_id=p.id and l.active))))) with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_submissions.school_id and (p.role='administrator' or (p.role='student' and exists(select 1 from public.student_account_links l where l.school_id=school_learning_submissions.school_id and l.student_id=school_learning_submissions.student_id and l.user_id=p.id and l.active)))));
create policy messages_read_participant on public.school_messages for select to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_messages.school_id and (p.role='administrator' or p.id=school_messages.sender_id or p.id=school_messages.recipient_id)));
create policy messages_send_school on public.school_messages for insert to authenticated with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_messages.school_id and p.id=school_messages.sender_id and p.role in ('administrator','teacher','bursar','parent','student')));
grant select,insert,update,delete on public.school_timetable_entries,public.school_inventory_items,public.school_learning_assignments,public.school_learning_submissions,public.school_messages to authenticated;
grant select,insert on public.school_inventory_transactions to authenticated;

-- Migration 2: stock ledger updates and narrower assignment visibility.
create or replace function public.apply_inventory_transaction()
returns trigger language plpgsql set search_path = '' as $$
declare current_qty numeric(12,2);
begin
 select quantity into current_qty from public.school_inventory_items where id=new.item_id and school_id=new.school_id for update;
 if not found then raise exception 'Inventory item was not found in this school.'; end if;
 if new.transaction_type='issued' then
  if current_qty<new.quantity then raise exception 'Insufficient stock: available %, requested %.',current_qty,new.quantity; end if;
  update public.school_inventory_items set quantity=quantity-new.quantity,updated_at=now() where id=new.item_id and school_id=new.school_id;
 else
  update public.school_inventory_items set quantity=quantity+new.quantity,updated_at=now() where id=new.item_id and school_id=new.school_id;
 end if;
 return new;
end; $$;
create trigger school_inventory_transaction_apply after insert on public.school_inventory_transactions for each row execute function public.apply_inventory_transaction();
drop policy if exists learning_assignments_read_school on public.school_learning_assignments;
create policy learning_assignments_read_school on public.school_learning_assignments for select to authenticated using (
 exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_assignments.school_id and (
  p.role='administrator'
  or (p.role='teacher' and (p.id=school_learning_assignments.teacher_id or exists(select 1 from public.teacher_assignments ta where ta.school_id=p.school_id and ta.teacher_id=p.id and ta.grade=school_learning_assignments.grade and (school_learning_assignments.stream is null or ta.stream=school_learning_assignments.stream))))
  or exists(select 1 from public.student_account_links l join public.students st on st.id=l.student_id and st.school_id=l.school_id where l.school_id=school_learning_assignments.school_id and l.user_id=p.id and l.active and st.grade=school_learning_assignments.grade and (school_learning_assignments.stream is null or st.stream=school_learning_assignments.stream))
 ))
);