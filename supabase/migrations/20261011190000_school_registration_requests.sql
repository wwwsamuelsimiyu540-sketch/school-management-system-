-- Ensure school registration requests are reproducible in fresh deployments.
-- Safe to re-run: existing requests and decisions are preserved.

create table if not exists public.school_registration_requests (
  id uuid primary key default gen_random_uuid(),
  school_name text not null check (char_length(trim(school_name)) between 2 and 200),
  code text not null check (char_length(trim(code)) between 2 and 30),
  county text,
  requested_by uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  review_notes text,
  created_at timestamptz not null default now()
);

create index if not exists school_registration_requests_requester_created_idx
  on public.school_registration_requests(requested_by, created_at desc);
create index if not exists school_registration_requests_status_created_idx
  on public.school_registration_requests(status, created_at desc);

alter table public.school_registration_requests enable row level security;

drop policy if exists school_requests_read_own_or_super_admin
  on public.school_registration_requests;
create policy school_requests_read_own_or_super_admin
  on public.school_registration_requests for select to authenticated
  using (requested_by = (select auth.uid()) or public.is_super_admin());

drop policy if exists school_requests_submit_as_principal
  on public.school_registration_requests;
create policy school_requests_submit_as_principal
  on public.school_registration_requests for insert to authenticated
  with check (
    requested_by = (select auth.uid())
    and status = 'pending'
    and reviewed_by is null
    and reviewed_at is null
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role = 'principal'
        and p.school_id is null
    )
  );

drop policy if exists school_requests_review_super_admin
  on public.school_registration_requests;
create policy school_requests_review_super_admin
  on public.school_registration_requests for update to authenticated
  using (public.is_super_admin())
  with check (
    public.is_super_admin()
    and status in ('pending', 'approved', 'rejected')
    and (reviewed_by is null or reviewed_by = (select auth.uid()))
  );

grant select, insert, update on public.school_registration_requests to authenticated;
