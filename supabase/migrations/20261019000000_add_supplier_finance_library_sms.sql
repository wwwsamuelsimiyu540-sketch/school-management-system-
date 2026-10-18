-- SAMIS/Zeraki-style feature parity additions: procurement, school finance,
-- bursaries, library loans, and an SMS outbox. Provider delivery requires credentials.
create table if not exists public.school_suppliers (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 supplier_name text not null, contact_person text, phone text, email text, address text, tax_pin text, notes text,
 active boolean not null default true, created_by uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.school_purchase_orders (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 order_number text not null, supplier_id uuid references public.school_suppliers(id) on delete set null,
 item_description text not null, store_location text, quantity numeric(12,2) not null check(quantity > 0),
 unit_cost numeric(12,2) not null check(unit_cost >= 0), order_date date not null default current_date,
 expected_date date, status text not null default 'draft' check(status in ('draft','approved','ordered','partially_received','received','cancelled')),
 received_quantity numeric(12,2) not null default 0 check(received_quantity >= 0), notes text,
 created_by uuid references public.profiles(id) on delete set null, approved_by uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(school_id,order_number), check(received_quantity <= quantity)
);
create table if not exists public.school_expenses (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 expense_date date not null default current_date, category text not null, description text not null,
 amount numeric(12,2) not null check(amount > 0), payment_method text not null default 'Cash', reference text,
 supplier_id uuid references public.school_suppliers(id) on delete set null, academic_year integer, term text,
 status text not null default 'approved' check(status in ('pending','approved','rejected')),
 recorded_by uuid references public.profiles(id) on delete set null, approved_by uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default now()
);
create table if not exists public.school_bursary_awards (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 student_id uuid not null references public.students(id) on delete cascade, award_name text not null,
 academic_year integer not null, term text not null, amount numeric(12,2) not null check(amount > 0),
 sponsor text, reason text, status text not null default 'approved' check(status in ('pending','approved','rejected')),
 approved_by uuid references public.profiles(id) on delete set null, created_by uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default now()
);
create table if not exists public.school_library_books (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 accession_number text not null, title text not null, author text, isbn text, category text, publisher text,
 publication_year integer, total_copies integer not null default 1 check(total_copies >= 0),
 available_copies integer not null default 1 check(available_copies >= 0), shelf_location text,
 condition text not null default 'Good', created_by uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(school_id,accession_number), check(available_copies <= total_copies)
);
create table if not exists public.school_library_loans (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 book_id uuid not null references public.school_library_books(id) on delete cascade,
 student_id uuid references public.students(id) on delete set null, borrower_name text not null,
 borrower_type text not null default 'student' check(borrower_type in ('student','staff')),
 issued_at timestamptz not null default now(), due_date date not null, returned_at timestamptz,
 fine_amount numeric(12,2) not null default 0 check(fine_amount >= 0), notes text,
 issued_by uuid references public.profiles(id) on delete set null, returned_by uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default now()
);
create table if not exists public.school_sms_outbox (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 recipient_name text, recipient_phone text not null, message text not null,
 message_type text not null default 'general' check(message_type in ('general','fees','results','attendance','announcement')),
 related_student_id uuid references public.students(id) on delete set null,
 status text not null default 'queued' check(status in ('queued','sent','failed','cancelled')),
 provider_reference text, provider_response text, requested_by uuid references public.profiles(id) on delete set null,
 sent_at timestamptz, created_at timestamptz not null default now()
);
create index if not exists school_suppliers_name_idx on public.school_suppliers(school_id,supplier_name);
create index if not exists school_purchase_orders_status_idx on public.school_purchase_orders(school_id,status,order_date desc);
create index if not exists school_expenses_date_idx on public.school_expenses(school_id,expense_date desc);
create index if not exists school_bursary_student_idx on public.school_bursary_awards(school_id,student_id,academic_year,term);
create index if not exists school_library_books_title_idx on public.school_library_books(school_id,title);
create index if not exists school_library_loans_due_idx on public.school_library_loans(school_id,due_date) where returned_at is null;
create index if not exists school_sms_outbox_status_idx on public.school_sms_outbox(school_id,status,created_at desc);
alter table public.school_suppliers enable row level security;
alter table public.school_purchase_orders enable row level security;
alter table public.school_expenses enable row level security;
alter table public.school_bursary_awards enable row level security;
alter table public.school_library_books enable row level security;
alter table public.school_library_loans enable row level security;
alter table public.school_sms_outbox enable row level security;
drop policy if exists suppliers_admin_bursar on public.school_suppliers;
create policy suppliers_admin_bursar on public.school_suppliers for all to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_suppliers.school_id and p.role in ('administrator','bursar'))) with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_suppliers.school_id and p.role in ('administrator','bursar')));
drop policy if exists purchase_orders_admin_bursar on public.school_purchase_orders;
create policy purchase_orders_admin_bursar on public.school_purchase_orders for all to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_purchase_orders.school_id and p.role in ('administrator','bursar'))) with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_purchase_orders.school_id and p.role in ('administrator','bursar')));
drop policy if exists expenses_admin_bursar on public.school_expenses;
create policy expenses_admin_bursar on public.school_expenses for all to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_expenses.school_id and p.role in ('administrator','bursar'))) with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_expenses.school_id and p.role in ('administrator','bursar')));
drop policy if exists bursary_admin_bursar on public.school_bursary_awards;
create policy bursary_admin_bursar on public.school_bursary_awards for all to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_bursary_awards.school_id and p.role in ('administrator','bursar'))) with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_bursary_awards.school_id and p.role in ('administrator','bursar')));
drop policy if exists library_books_school_read on public.school_library_books;
create policy library_books_school_read on public.school_library_books for select to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_library_books.school_id));
drop policy if exists library_books_admin_write on public.school_library_books;
create policy library_books_admin_write on public.school_library_books for all to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_library_books.school_id and p.role in ('administrator','teacher'))) with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_library_books.school_id and p.role in ('administrator','teacher')));
drop policy if exists library_loans_school_read on public.school_library_loans;
create policy library_loans_school_read on public.school_library_loans for select to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_library_loans.school_id and p.role in ('administrator','teacher','bursar')));
drop policy if exists library_loans_admin_write on public.school_library_loans;
create policy library_loans_admin_write on public.school_library_loans for all to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_library_loans.school_id and p.role in ('administrator','teacher'))) with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_library_loans.school_id and p.role in ('administrator','teacher')));
drop policy if exists sms_outbox_school_access on public.school_sms_outbox;
create policy sms_outbox_school_access on public.school_sms_outbox for all to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_sms_outbox.school_id and p.role in ('administrator','bursar'))) with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_sms_outbox.school_id and p.role in ('administrator','bursar')));
grant select,insert,update,delete on public.school_suppliers,public.school_purchase_orders,public.school_expenses,public.school_bursary_awards,public.school_library_books,public.school_library_loans,public.school_sms_outbox to authenticated;
