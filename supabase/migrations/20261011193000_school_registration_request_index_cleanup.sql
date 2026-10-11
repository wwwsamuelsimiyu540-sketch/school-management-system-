-- Remove duplicate indexes created by the initial version of the registration migration.
drop index if exists public.school_registration_requests_requester_idx;
drop index if exists public.school_registration_requests_status_idx;
create index if not exists school_registration_requests_requester_created_idx
  on public.school_registration_requests(requested_by, created_at desc);
create index if not exists school_registration_requests_status_created_idx
  on public.school_registration_requests(status, created_at desc);
