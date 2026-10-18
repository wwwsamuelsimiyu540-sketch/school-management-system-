create table if not exists public.school_learning_resources (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 title text not null, description text, resource_type text not null default 'notes' check(resource_type in ('notes','revision','video','link','worksheet','other')),
 learning_area text, grade text not null, stream text, resource_url text not null,
 created_by uuid not null references public.profiles(id) on delete cascade,
 status text not null default 'published' check(status in ('draft','published','archived')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists school_learning_resources_class_idx on public.school_learning_resources(school_id,grade,stream,learning_area,status);
create index if not exists school_learning_resources_created_by_idx on public.school_learning_resources(created_by);
alter table public.school_learning_resources enable row level security;
drop policy if exists learning_resources_read_scope on public.school_learning_resources;
create policy learning_resources_read_scope on public.school_learning_resources for select to authenticated
using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_resources.school_id and (
 p.role='administrator'
 or (p.role='teacher' and exists(select 1 from public.teacher_assignments ta where ta.school_id=p.school_id and ta.teacher_id=p.id and ta.grade=school_learning_resources.grade and (school_learning_resources.stream is null or ta.stream=school_learning_resources.stream)))
 or exists(select 1 from public.student_account_links l join public.students st on st.id=l.student_id and st.school_id=l.school_id where l.school_id=school_learning_resources.school_id and l.user_id=p.id and l.active and st.grade=school_learning_resources.grade and (school_learning_resources.stream is null or st.stream=school_learning_resources.stream))
)));
drop policy if exists learning_resources_write_scope on public.school_learning_resources;
create policy learning_resources_write_scope on public.school_learning_resources for all to authenticated
using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_resources.school_id and (
 p.role='administrator' or (p.role='teacher' and p.id=school_learning_resources.created_by and exists(select 1 from public.teacher_assignments ta where ta.school_id=p.school_id and ta.teacher_id=p.id and ta.grade=school_learning_resources.grade and (school_learning_resources.stream is null or ta.stream=school_learning_resources.stream)))
)))
with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_resources.school_id and p.id=school_learning_resources.created_by and (
 p.role='administrator' or (p.role='teacher' and exists(select 1 from public.teacher_assignments ta where ta.school_id=p.school_id and ta.teacher_id=p.id and ta.grade=school_learning_resources.grade and (school_learning_resources.stream is null or ta.stream=school_learning_resources.stream)))
)));
grant select,insert,update,delete on public.school_learning_resources to authenticated;