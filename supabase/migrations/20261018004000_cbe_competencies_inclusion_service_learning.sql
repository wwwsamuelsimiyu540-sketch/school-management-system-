-- Additional CBE/CBC structures for competencies, inclusive adjustments and community service learning.
create table if not exists public.school_competency_observations (
 id uuid primary key default gen_random_uuid(),
 school_id uuid not null references public.schools(id) on delete cascade,
 student_id uuid not null references public.students(id) on delete cascade,
 domain_type text not null check (domain_type in ('core_competency','value','pci')),
 domain_name text not null,
 learning_area text,
 achievement_level text not null,
 evidence text,
 next_steps text,
 recorded_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now()
);
create table if not exists public.school_learner_accommodations (
 id uuid primary key default gen_random_uuid(),
 school_id uuid not null references public.schools(id) on delete cascade,
 student_id uuid not null references public.students(id) on delete cascade,
 accommodation_type text not null check (accommodation_type in ('instructional','assessment','accessibility','communication','other')),
 details text not null,
 review_date date,
 status text not null default 'active' check (status in ('active','review','closed')),
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.school_service_learning_projects (
 id uuid primary key default gen_random_uuid(),
 school_id uuid not null references public.schools(id) on delete cascade,
 title text not null,
 description text,
 learning_area text,
 community_partner text,
 start_date date,
 end_date date,
 status text not null default 'planned' check (status in ('planned','active','completed','cancelled')),
 outcomes text,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists school_competency_observations_school_student_idx on public.school_competency_observations(school_id,student_id,created_at desc);
create index if not exists school_learner_accommodations_school_student_idx on public.school_learner_accommodations(school_id,student_id,status);
create index if not exists school_service_learning_projects_school_status_idx on public.school_service_learning_projects(school_id,status,created_at desc);
alter table public.school_competency_observations enable row level security;
alter table public.school_learner_accommodations enable row level security;
alter table public.school_service_learning_projects enable row level security;

-- Competency records: school staff see assigned learner records; learners/guardians see linked learner records.
create policy cbe_competency_select on public.school_competency_observations for select to authenticated using (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_competency_observations.school_id)
 and (
  exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='administrator')
  or exists (select 1 from public.profiles p join public.students s on s.school_id=p.school_id join public.teacher_assignments ta on ta.school_id=s.school_id and ta.teacher_id=p.id and ta.grade=s.grade and ta.stream=s.stream where p.id=(select auth.uid()) and p.role='teacher' and s.id=school_competency_observations.student_id)
  or exists (select 1 from public.student_account_links l where l.user_id=(select auth.uid()) and l.student_id=school_competency_observations.student_id and l.active=true)
 )
);
create policy cbe_competency_insert on public.school_competency_observations for insert to authenticated with check (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_competency_observations.school_id and p.role='administrator')
 or (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_competency_observations.school_id and p.role='teacher') and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_competency_observations.student_id and s.school_id=school_competency_observations.school_id and ta.teacher_id=(select auth.uid())))
);
create policy cbe_competency_update on public.school_competency_observations for update to authenticated using (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_competency_observations.school_id and p.role='administrator')
 or (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_competency_observations.school_id and p.role='teacher') and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_competency_observations.student_id and s.school_id=school_competency_observations.school_id and ta.teacher_id=(select auth.uid())))
) with check (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_competency_observations.school_id and p.role='administrator')
 or (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_competency_observations.school_id and p.role='teacher') and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_competency_observations.student_id and s.school_id=school_competency_observations.school_id and ta.teacher_id=(select auth.uid())))
);
create policy cbe_competency_delete on public.school_competency_observations for delete to authenticated using (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_competency_observations.school_id and p.role='administrator')
);

-- Accommodation details are intentionally restricted to school staff, not learner/parent accounts.
create policy cbe_accommodation_select on public.school_learner_accommodations for select to authenticated using (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learner_accommodations.school_id and (p.role='administrator' or (p.role='teacher' and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learner_accommodations.student_id and s.school_id=p.school_id and ta.teacher_id=p.id))))
);
create policy cbe_accommodation_insert on public.school_learner_accommodations for insert to authenticated with check (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learner_accommodations.school_id and (p.role='administrator' or (p.role='teacher' and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learner_accommodations.student_id and s.school_id=p.school_id and ta.teacher_id=p.id))))
);
create policy cbe_accommodation_update on public.school_learner_accommodations for update to authenticated using (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learner_accommodations.school_id and (p.role='administrator' or (p.role='teacher' and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learner_accommodations.student_id and s.school_id=p.school_id and ta.teacher_id=p.id))))
) with check (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learner_accommodations.school_id and (p.role='administrator' or (p.role='teacher' and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learner_accommodations.student_id and s.school_id=p.school_id and ta.teacher_id=p.id))))
);
create policy cbe_accommodation_delete on public.school_learner_accommodations for delete to authenticated using (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learner_accommodations.school_id and p.role='administrator')
);

-- Community projects are visible to staff within the school and are managed by administrators/teachers.
create policy cbe_service_projects_select on public.school_service_learning_projects for select to authenticated using (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_service_learning_projects.school_id and p.role in ('administrator','teacher'))
);
create policy cbe_service_projects_insert on public.school_service_learning_projects for insert to authenticated with check (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_service_learning_projects.school_id and p.role in ('administrator','teacher'))
);
create policy cbe_service_projects_update on public.school_service_learning_projects for update to authenticated using (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_service_learning_projects.school_id and p.role in ('administrator','teacher'))
) with check (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_service_learning_projects.school_id and p.role in ('administrator','teacher'))
);
create policy cbe_service_projects_delete on public.school_service_learning_projects for delete to authenticated using (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_service_learning_projects.school_id and p.role='administrator')
);
grant select,insert,update,delete on public.school_competency_observations to authenticated;
grant select,insert,update,delete on public.school_learner_accommodations to authenticated;
grant select,insert,update,delete on public.school_service_learning_projects to authenticated;
