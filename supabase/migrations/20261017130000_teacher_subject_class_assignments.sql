-- Teacher subject/class assignments for real school workflows.
-- Teachers may teach multiple subjects and classes; each row grants one subject in one class.
create table if not exists public.teacher_subject_assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  teacher_id uuid not null references public.teachers(id) on delete cascade,
  class_id uuid not null references public.school_classes(id) on delete cascade,
  subject text not null check (length(trim(subject)) > 0),
  created_at timestamptz not null default now(),
  unique (teacher_id, class_id, subject)
);

create index if not exists teacher_subject_assignments_teacher_idx
  on public.teacher_subject_assignments (teacher_id, school_id);
create index if not exists teacher_subject_assignments_class_idx
  on public.teacher_subject_assignments (class_id, subject);

alter table public.teacher_subject_assignments enable row level security;
drop policy if exists teacher_assignments_read on public.teacher_subject_assignments;
create policy teacher_assignments_read on public.teacher_subject_assignments
  for select to authenticated using (
    school_id = public.get_user_school_id()
    and (
      public.is_super_admin()
      or exists (
        select 1 from public.profiles p
        join public.teachers t on t.user_id = p.id
        where p.id = auth.uid() and p.role = 'teacher' and t.id = teacher_id
      )
      or exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and p.role = 'principal' and p.school_id = school_id
      )
    )
  );

drop policy if exists teacher_assignments_admin_manage on public.teacher_subject_assignments;
create policy teacher_assignments_admin_manage on public.teacher_subject_assignments
  for all to authenticated
  using (
    public.is_super_admin()
    or (school_id = public.get_user_school_id() and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'principal' and p.school_id = school_id
    ))
  )
  with check (
    public.is_super_admin()
    or (school_id = public.get_user_school_id() and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'principal' and p.school_id = school_id
    ))
  );

grant select, insert, update, delete on public.teacher_subject_assignments to authenticated;
