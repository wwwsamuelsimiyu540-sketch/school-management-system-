-- Teacher subject/class assignments for real school workflows.
-- Each row grants one teacher one subject in one class/stream.
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
    public.is_super_admin()
    or (
      teacher_subject_assignments.school_id = public.get_user_school_id()
      and (
        exists (
          select 1 from public.profiles p
          join public.teachers t on t.user_id = p.id
          where p.id = (select auth.uid())
            and p.role = 'teacher'
            and t.id = teacher_subject_assignments.teacher_id
            and t.school_id = teacher_subject_assignments.school_id
        )
        or exists (
          select 1 from public.profiles p
          where p.id = (select auth.uid())
            and p.role = 'principal'
            and p.school_id = teacher_subject_assignments.school_id
        )
      )
    )
  );

drop policy if exists teacher_assignments_admin_manage on public.teacher_subject_assignments;
create policy teacher_assignments_admin_manage on public.teacher_subject_assignments
  for all to authenticated
  using (
    public.is_super_admin()
    or (
      teacher_subject_assignments.school_id = public.get_user_school_id()
      and exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid())
          and p.role = 'principal'
          and p.school_id = teacher_subject_assignments.school_id
      )
    )
  )
  with check (
    public.is_super_admin()
    or (
      teacher_subject_assignments.school_id = public.get_user_school_id()
      and exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid())
          and p.role = 'principal'
          and p.school_id = teacher_subject_assignments.school_id
      )
    )
  );

grant select, insert, update, delete on public.teacher_subject_assignments to authenticated;

-- Prevent an assignment from linking records belonging to different schools.
create or replace function public.validate_teacher_subject_assignment_school()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.teachers t
    join public.school_classes c on c.id = new.class_id
    where t.id = new.teacher_id
      and t.school_id = new.school_id
      and c.school_id = new.school_id
  ) then
    raise exception 'Teacher and class must belong to the selected school';
  end if;
  return new;
end;
$$;

drop trigger if exists teacher_subject_assignment_school_guard on public.teacher_subject_assignments;
create trigger teacher_subject_assignment_school_guard
before insert or update of school_id, teacher_id, class_id
on public.teacher_subject_assignments
for each row execute function public.validate_teacher_subject_assignment_school();
