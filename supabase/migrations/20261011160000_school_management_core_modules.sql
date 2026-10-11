-- Friends Day Senior School Lukhome: school management schema extension
-- Safe/idempotent: keeps existing schools, profiles, students, exam_marks and platform tables.

create table if not exists public.teachers (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null, staff_no text, full_name text not null,
  subject text, phone text, email text, created_at timestamptz not null default now()
);
create table if not exists public.school_classes (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  name text not null, grade_level text, class_teacher_id uuid references public.teachers(id) on delete set null,
  room text, capacity integer not null default 40 check (capacity > 0), academic_year text,
  created_at timestamptz not null default now(), unique (school_id, name, academic_year)
);
create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  class_id uuid references public.school_classes(id) on delete set null,
  attendance_date date not null default current_date,
  status text not null check (status in ('present','absent','late','excused')), note text,
  marked_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now(),
  unique (student_id, attendance_date)
);
create table if not exists public.fee_payments (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade, term text not null, academic_year text,
  amount_due numeric(12,2) not null default 0 check (amount_due >= 0),
  amount_paid numeric(12,2) not null default 0 check (amount_paid >= 0), payment_date date, receipt_no text,
  recorded_by uuid references public.profiles(id) on delete set null, note text, created_at timestamptz not null default now()
);
create table if not exists public.school_events (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  title text not null, description text, starts_at timestamptz, ends_at timestamptz,
  event_type text not null default 'general', created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.school_announcements (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  title text not null, body text not null, audience text not null default 'all'
  check (audience in ('all','staff','parents','students')), published boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.parent_student_links (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  parent_user_id uuid not null references public.profiles(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  relationship text not null default 'Parent/Guardian', created_at timestamptz not null default now(),
  unique(parent_user_id, student_id)
);
create table if not exists public.school_messages (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_user_id uuid references public.profiles(id) on delete set null,
  channel text not null default 'internal' check (channel in ('internal','email','whatsapp')),
  subject text, message text not null, status text not null default 'draft'
  check (status in ('draft','sent','read')), created_at timestamptz not null default now()
);

create index if not exists teachers_school_idx on public.teachers(school_id);
create index if not exists classes_school_idx on public.school_classes(school_id);
create index if not exists attendance_school_date_idx on public.attendance_records(school_id, attendance_date);
create index if not exists attendance_student_idx on public.attendance_records(student_id);
create index if not exists fee_payments_school_idx on public.fee_payments(school_id);
create index if not exists fee_payments_student_idx on public.fee_payments(student_id);
create index if not exists events_school_start_idx on public.school_events(school_id, starts_at);
create index if not exists announcements_school_created_idx on public.school_announcements(school_id, created_at desc);
create index if not exists parent_links_user_idx on public.parent_student_links(parent_user_id, student_id);

alter table public.teachers enable row level security;
alter table public.school_classes enable row level security;
alter table public.attendance_records enable row level security;
alter table public.fee_payments enable row level security;
alter table public.school_events enable row level security;
alter table public.school_announcements enable row level security;
alter table public.parent_student_links enable row level security;
alter table public.school_messages enable row level security;

drop policy if exists teachers_school_read on public.teachers;
create policy teachers_school_read on public.teachers for select to authenticated using (school_id = public.get_user_school_id() or public.is_super_admin());
drop policy if exists teachers_staff_manage on public.teachers;
create policy teachers_staff_manage on public.teachers for all to authenticated
using ((school_id = public.get_user_school_id() and public.is_school_staff()) or public.is_super_admin())
with check ((school_id = public.get_user_school_id() and public.is_school_staff()) or public.is_super_admin());

drop policy if exists classes_school_read on public.school_classes;
create policy classes_school_read on public.school_classes for select to authenticated using (school_id = public.get_user_school_id() or public.is_super_admin());
drop policy if exists classes_staff_manage on public.school_classes;
create policy classes_staff_manage on public.school_classes for all to authenticated
using ((school_id = public.get_user_school_id() and public.is_school_staff()) or public.is_super_admin())
with check ((school_id = public.get_user_school_id() and public.is_school_staff()) or public.is_super_admin());

drop policy if exists attendance_school_read on public.attendance_records;
create policy attendance_school_read on public.attendance_records for select to authenticated using (school_id = public.get_user_school_id() or public.is_super_admin());
drop policy if exists attendance_staff_manage on public.attendance_records;
create policy attendance_staff_manage on public.attendance_records for all to authenticated
using ((school_id = public.get_user_school_id() and public.is_school_staff()) or public.is_super_admin())
with check ((school_id = public.get_user_school_id() and public.is_school_staff()) or public.is_super_admin());

drop policy if exists fees_school_read on public.fee_payments;
create policy fees_school_read on public.fee_payments for select to authenticated using (school_id = public.get_user_school_id() or public.is_super_admin());
drop policy if exists fees_authorized_manage on public.fee_payments;
create policy fees_authorized_manage on public.fee_payments for all to authenticated
using ((school_id = public.get_user_school_id() and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('principal','bursar'))) or public.is_super_admin())
with check ((school_id = public.get_user_school_id() and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('principal','bursar'))) or public.is_super_admin());

drop policy if exists events_school_read on public.school_events;
create policy events_school_read on public.school_events for select to authenticated using (school_id = public.get_user_school_id() or public.is_super_admin());
drop policy if exists events_staff_manage on public.school_events;
create policy events_staff_manage on public.school_events for all to authenticated
using ((school_id = public.get_user_school_id() and public.is_school_staff()) or public.is_super_admin())
with check ((school_id = public.get_user_school_id() and public.is_school_staff()) or public.is_super_admin());

drop policy if exists announcements_school_read on public.school_announcements;
create policy announcements_school_read on public.school_announcements for select to authenticated
using ((school_id = public.get_user_school_id() and published = true) or (school_id = public.get_user_school_id() and public.is_school_staff()) or public.is_super_admin());
drop policy if exists announcements_staff_manage on public.school_announcements;
create policy announcements_staff_manage on public.school_announcements for all to authenticated
using ((school_id = public.get_user_school_id() and public.is_school_staff()) or public.is_super_admin())
with check ((school_id = public.get_user_school_id() and public.is_school_staff()) or public.is_super_admin());

drop policy if exists parent_links_parent_read on public.parent_student_links;
create policy parent_links_parent_read on public.parent_student_links for select to authenticated using (parent_user_id = auth.uid() or public.is_super_admin());
drop policy if exists parent_links_staff_manage on public.parent_student_links;
create policy parent_links_staff_manage on public.parent_student_links for all to authenticated
using ((school_id = public.get_user_school_id() and public.is_school_staff()) or public.is_super_admin())
with check ((school_id = public.get_user_school_id() and public.is_school_staff()) or public.is_super_admin());

drop policy if exists school_messages_participant_read on public.school_messages;
create policy school_messages_participant_read on public.school_messages for select to authenticated
using (((sender_id = auth.uid() or recipient_user_id = auth.uid()) and school_id = public.get_user_school_id()) or public.is_super_admin());
drop policy if exists school_messages_sender_insert on public.school_messages;
create policy school_messages_sender_insert on public.school_messages for insert to authenticated
with check (sender_id = auth.uid() and school_id = public.get_user_school_id());
drop policy if exists school_messages_participant_update on public.school_messages;
create policy school_messages_participant_update on public.school_messages for update to authenticated
using (((sender_id = auth.uid() or recipient_user_id = auth.uid()) and school_id = public.get_user_school_id()) or public.is_super_admin())
with check (((sender_id = auth.uid() or recipient_user_id = auth.uid()) and school_id = public.get_user_school_id()) or public.is_super_admin());

drop policy if exists platform_activity_school_insert on public.platform_activity_log;
create policy platform_activity_school_insert on public.platform_activity_log for insert to authenticated
with check (actor_id = auth.uid() and (school_id = public.get_user_school_id() or public.is_super_admin()));

grant select, insert, update, delete on public.teachers, public.school_classes, public.attendance_records,
  public.fee_payments, public.school_events, public.school_announcements, public.parent_student_links,
  public.school_messages to authenticated;
grant select, insert on public.platform_activity_log to authenticated;
grant select, insert, update on public.platform_user_presence to authenticated;
