create table if not exists public.school_supplier_invoices (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 supplier_id uuid references public.school_suppliers(id) on delete set null,
 invoice_number text not null, invoice_date date not null default current_date, due_date date,
 description text not null, amount numeric(12,2) not null check(amount > 0),
 amount_paid numeric(12,2) not null default 0 check(amount_paid >= 0),
 status text not null default 'unpaid' check(status in ('unpaid','partially_paid','paid','overdue','cancelled')),
 payment_reference text, notes text, recorded_by uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(school_id,invoice_number), check(amount_paid <= amount)
);
create index if not exists school_supplier_invoices_due_idx on public.school_supplier_invoices(school_id,status,due_date);
alter table public.school_supplier_invoices enable row level security;
drop policy if exists supplier_invoices_admin_bursar on public.school_supplier_invoices;
create policy supplier_invoices_admin_bursar on public.school_supplier_invoices for all to authenticated
using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_supplier_invoices.school_id and p.role in ('administrator','bursar')))
with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_supplier_invoices.school_id and p.role in ('administrator','bursar')));
grant select,insert,update,delete on public.school_supplier_invoices to authenticated;