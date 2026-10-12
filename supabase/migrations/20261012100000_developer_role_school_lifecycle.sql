-- Platform owner role and school lifecycle.
-- Existing super_admin accounts are converted to developer accounts and detached from schools.
-- Keep is_super_admin() as a compatibility helper so existing RLS policies remain valid.

alter table public.schools
  add column if not exists status text not null default 'approved';

update public.profiles
set role = 'developer', school_id = null
where role = 'super_admin';

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'developer'
      and p.school_id is null
  );
$$;

create or replace function public.is_developer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin();
$$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_developer_has_no_school'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_developer_has_no_school
      check (role <> 'developer' or school_id is null) not valid;
  end if;
end
$$;

-- Enforce the invariant for all existing rows after the role conversion above.
alter table public.profiles
  validate constraint profiles_developer_has_no_school;

create index if not exists schools_status_idx on public.schools(status);
