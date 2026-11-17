create or replace view public.school_library_student_directory
with (security_invoker = false, security_barrier = true)
as
select s.id, s.school_id, s.full_name, s.admission_no, s.grade, s.stream
from public.students s
where exists (
  select 1
  from public.profiles p
  where p.id = (select auth.uid())
    and p.school_id = s.school_id
    and p.role = 'librarian'
);

grant select on public.school_library_student_directory to authenticated;
