-- Additive CBE/CBC support. Existing school-management tables and records are not altered or dropped.
create table if not exists public.school_learning_portfolios (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  title text not null,
  description text,
  learning_area text,
  evidence_type text not null default 'project' check (evidence_type in ('project','practical','presentation','observation','reflection','document','other')),
  evidence_url text,
  evidence_text text,
  competency_tags text[] not null default '{}',
  recorded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.school_learning_support_plans (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  learning_area text not null,
  concern text not null,
  support_action text not null,
  target_date date,
  review_date date,
  status text not null default 'active' check (status in ('active','review','achieved','closed')),
  outcome_notes text,
  created_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.school_learning_reflections (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  learning_area text,
  reflection_text text not null,
  strengths text,
  next_steps text,
  recorded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.school_assessment_moderation (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  assessment_type text not null,
  assessment_id uuid,
  grade text,
  stream text,
  learning_area text,
  moderation_status text not null default 'pending' check (moderation_status in ('pending','reviewed','approved','returned')),
  notes text,
  moderator_id uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create index if not exists school_learning_portfolios_school_student_idx on public.school_learning_portfolios(school_id, student_id, created_at desc);
create index if not exists school_learning_support_school_student_idx on public.school_learning_support_plans(school_id, student_id, status);
create index if not exists school_learning_reflections_school_student_idx on public.school_learning_reflections(school_id, student_id, created_at desc);
create index if not exists school_assessment_moderation_school_status_idx on public.school_assessment_moderation(school_id, moderation_status, created_at desc);

-- Restrict every new record to its school. Administrators manage records; teachers can
-- record learning evidence/support for learners in their school. Students/parents can
-- read only evidence linked to their own securely linked student records.
alter table public.school_learning_portfolios enable row level security;
alter table public.school_learning_support_plans enable row level security;
alter table public.school_learning_reflections enable row level security;
alter table public.school_assessment_moderation enable row level security;

drop policy if exists cbe_portfolio_select on public.school_learning_portfolios;
create policy cbe_portfolio_select on public.school_learning_portfolios for select to authenticated
using (
  exists (select 1 from public.profiles p where p.id=auth.uid() and p.school_id=school_learning_portfolios.school_id)
  and (
    exists (select 1 from public.profiles p where p.id=auth.uid() and p.role in ('administrator','developer','teacher'))
    or exists (select 1 from public.student_account_links l where l.user_id=auth.uid() and l.student_id=school_learning_portfolios.student_id and l.active=true)
  )
);
drop policy if exists cbe_portfolio_write on public.school_learning_portfolios;
create policy cbe_portfolio_write on public.school_learning_portfolios for all to authenticated
using (exists (select 1 from public.profiles p where p.id=auth.uid() and p.school_id=school_learning_portfolios.school_id and p.role in ('administrator','teacher')))
with check (
  exists (select 1 from public.profiles p where p.id=auth.uid() and p.school_id=school_learning_portfolios.school_id and p.role in ('administrator','teacher'))
  and exists (select 1 from public.students s where s.id=school_learning_portfolios.student_id and s.school_id=school_learning_portfolios.school_id)
);

drop policy if exists cbe_support_select on public.school_learning_support_plans;
create policy cbe_support_select on public.school_learning_support_plans for select to authenticated
using (
  exists (select 1 from public.profiles p where p.id=auth.uid() and p.school_id=school_learning_support_plans.school_id)
  and (
    exists (select 1 from public.profiles p where p.id=auth.uid() and p.role in ('administrator','teacher'))
    or exists (select 1 from public.student_account_links l where l.user_id=auth.uid() and l.student_id=school_learning_support_plans.student_id and l.active=true)
  )
);
drop policy if exists cbe_support_write on public.school_learning_support_plans;
create policy cbe_support_write on public.school_learning_support_plans for all to authenticated
using (exists (select 1 from public.profiles p where p.id=auth.uid() and p.school_id=school_learning_support_plans.school_id and p.role in ('administrator','teacher')))
with check (
  exists (select 1 from public.profiles p where p.id=auth.uid() and p.school_id=school_learning_support_plans.school_id and p.role in ('administrator','teacher'))
  and exists (select 1 from public.students s where s.id=school_learning_support_plans.student_id and s.school_id=school_learning_support_plans.school_id)
);

drop policy if exists cbe_reflections_select on public.school_learning_reflections;
create policy cbe_reflections_select on public.school_learning_reflections for select to authenticated
using (
  exists (select 1 from public.profiles p where p.id=auth.uid() and p.school_id=school_learning_reflections.school_id)
  and (
    exists (select 1 from public.profiles p where p.id=auth.uid() and p.role in ('administrator','teacher'))
    or exists (select 1 from public.student_account_links l where l.user_id=auth.uid() and l.student_id=school_learning_reflections.student_id and l.active=true)
  )
);
drop policy if exists cbe_reflections_write on public.school_learning_reflections;
create policy cbe_reflections_write on public.school_learning_reflections for all to authenticated
using (exists (select 1 from public.profiles p where p.id=auth.uid() and p.school_id=school_learning_reflections.school_id and p.role in ('administrator','teacher')))
with check (
  exists (select 1 from public.profiles p where p.id=auth.uid() and p.school_id=school_learning_reflections.school_id and p.role in ('administrator','teacher'))
  and exists (select 1 from public.students s where s.id=school_learning_reflections.student_id and s.school_id=school_learning_reflections.school_id)
);

drop policy if exists cbe_moderation_select on public.school_assessment_moderation;
create policy cbe_moderation_select on public.school_assessment_moderation for select to authenticated
using (exists (select 1 from public.profiles p where p.id=auth.uid() and p.school_id=school_assessment_moderation.school_id and p.role in ('administrator','teacher')));
drop policy if exists cbe_moderation_write on public.school_assessment_moderation;
create policy cbe_moderation_write on public.school_assessment_moderation for all to authenticated
using (exists (select 1 from public.profiles p where p.id=auth.uid() and p.school_id=school_assessment_moderation.school_id and p.role='administrator'))
with check (exists (select 1 from public.profiles p where p.id=auth.uid() and p.school_id=school_assessment_moderation.school_id and p.role='administrator'));
