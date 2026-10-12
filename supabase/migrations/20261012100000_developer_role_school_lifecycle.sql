-- Platform owner role and school lifecycle.
-- Keep the platform-wide role as super_admin; it must not belong to a school.
-- Keep is_super_admin() as the canonical helper for existing RLS policies.

alter table public.schools
  add column if not exists status text not null default 'approved';

-- Ensure existing super_admin accounts remain platform-wide.
update public.profiles
set school_id = null
where role = 'super_admin';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_super_admin_has_no_school'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_super_admin_has_no_school
      check (role <> 'super_admin' or school_id is null) not valid;
  end if;
end
$$;

alter table public.profiles
  validate constraint profiles_super_admin_has_no_school;

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
      and p.role = 'super_admin'
      and p.school_id is null
  );
$$;

-- Compatibility alias for any policies or code that still call is_developer().
create or replace function public.is_developer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin();
$$;

create index if not exists schools_status_idx on public.schools(status);
