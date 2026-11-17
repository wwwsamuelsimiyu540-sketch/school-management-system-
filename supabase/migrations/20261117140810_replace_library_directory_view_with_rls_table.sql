drop view if exists public.school_library_student_directory;

create table public.school_library_student_directory (
  id uuid primary key references public.students(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  full_name text not null,
  admission_no text,
  grade text,
  stream text
);

alter table public.school_library_student_directory enable row level security;
grant select on public.school_library_student_directory to authenticated;

drop policy if exists "library_student_directory_librarian_read" on public.school_library_student_directory;
create policy "library_student_directory_librarian_read"
on public.school_library_student_directory
for select to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.school_id = school_library_student_directory.school_id
      and p.role = 'librarian'
  )
);

create schema if not exists private;

create or replace function private.sync_school_library_student_directory()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  if tg_op = 'DELETE' then
    delete from public.school_library_student_directory where id = old.id;
    return old;
  end if;

  insert into public.school_library_student_directory
    (id, school_id, full_name, admission_no, grade, stream)
  values
    (new.id, new.school_id, new.full_name, new.admission_no, new.grade, new.stream)
  on conflict (id) do update set
    school_id = excluded.school_id,
    full_name = excluded.full_name,
    admission_no = excluded.admission_no,
    grade = excluded.grade,
    stream = excluded.stream;

  return new;
end;
$function$;

revoke all on function private.sync_school_library_student_directory() from public, anon, authenticated;

drop trigger if exists sync_school_library_student_directory on public.students;
create trigger sync_school_library_student_directory
after insert or update or delete on public.students
for each row execute function private.sync_school_library_student_directory();

insert into public.school_library_student_directory (id, school_id, full_name, admission_no, grade, stream)
select id, school_id, full_name, admission_no, grade, stream
from public.students
on conflict (id) do update set
  school_id = excluded.school_id,
  full_name = excluded.full_name,
  admission_no = excluded.admission_no,
  grade = excluded.grade,
  stream = excluded.stream;
