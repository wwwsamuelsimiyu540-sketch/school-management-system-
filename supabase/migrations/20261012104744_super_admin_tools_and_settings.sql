-- Supabase-backed settings and work records for Super Admin tools.
create table if not exists public.platform_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table public.platform_settings enable row level security;
drop policy if exists platform_settings_super_admin_all on public.platform_settings;
create policy platform_settings_super_admin_all on public.platform_settings
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

create table if not exists public.platform_admin_records (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  feature_name text not null,
  title text not null,
  details text not null default '',
  status text not null default 'open',
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists platform_admin_records_category_created_idx
  on public.platform_admin_records(category, created_at desc);
create index if not exists platform_admin_records_status_idx
  on public.platform_admin_records(status);
alter table public.platform_admin_records enable row level security;
drop policy if exists platform_admin_records_super_admin_all on public.platform_admin_records;
create policy platform_admin_records_super_admin_all on public.platform_admin_records
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());
