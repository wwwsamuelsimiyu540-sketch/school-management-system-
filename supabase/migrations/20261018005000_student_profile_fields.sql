-- Extend student records with profile fields used by the Students panel.
-- Safe for existing data: nullable fields and a default status are added.
alter table public.students add column if not exists gender text;
alter table public.students add column if not exists phone text;
alter table public.students add column if not exists status text not null default 'Active';
