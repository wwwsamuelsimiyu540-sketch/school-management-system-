drop policy if exists "fees delete admin only" on public.fee_payments;
drop policy if exists "fees delete bursar only" on public.fee_payments;
create policy "fees delete bursar only" on public.fee_payments
for delete to authenticated
using ((select is_platform_developer()) or (
  school_id = (select p.school_id from public.profiles p where p.id=(select auth.uid()))
  and exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='bursar')
));

drop policy if exists "fees insert authorized" on public.fee_payments;
drop policy if exists "fees insert bursar only" on public.fee_payments;
create policy "fees insert bursar only" on public.fee_payments
for insert to authenticated
with check ((select is_platform_developer()) or (
  school_id = (select p.school_id from public.profiles p where p.id=(select auth.uid()))
  and exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='bursar')
  and exists (select 1 from public.students s where s.id=fee_payments.student_id and s.school_id=fee_payments.school_id)
));

drop policy if exists "fees update authorized" on public.fee_payments;
drop policy if exists "fees update bursar only" on public.fee_payments;
create policy "fees update bursar only" on public.fee_payments
for update to authenticated
using ((select is_platform_developer()) or (
  school_id = (select p.school_id from public.profiles p where p.id=(select auth.uid()))
  and exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='bursar')
))
with check ((select is_platform_developer()) or (
  school_id = (select p.school_id from public.profiles p where p.id=(select auth.uid()))
  and exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='bursar')
  and exists (select 1 from public.students s where s.id=fee_payments.student_id and s.school_id=fee_payments.school_id)
));

drop policy if exists "fee charges delete authorized" on public.student_fee_charges;
drop policy if exists "fee charges delete bursar only" on public.student_fee_charges;
create policy "fee charges delete bursar only" on public.student_fee_charges
for delete to authenticated
using ((select is_platform_developer()) or (
  school_id = (select p.school_id from public.profiles p where p.id=(select auth.uid()))
  and exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='bursar')
));

drop policy if exists "fee charges insert authorized" on public.student_fee_charges;
drop policy if exists "fee charges insert bursar only" on public.student_fee_charges;
create policy "fee charges insert bursar only" on public.student_fee_charges
for insert to authenticated
with check ((select is_platform_developer()) or (
  school_id = (select p.school_id from public.profiles p where p.id=(select auth.uid()))
  and exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='bursar')
  and exists (select 1 from public.students s where s.id=student_fee_charges.student_id and s.school_id=student_fee_charges.school_id)
));

drop policy if exists "fee charges update authorized" on public.student_fee_charges;
drop policy if exists "fee charges update bursar only" on public.student_fee_charges;
create policy "fee charges update bursar only" on public.student_fee_charges
for update to authenticated
using ((select is_platform_developer()) or (
  school_id = (select p.school_id from public.profiles p where p.id=(select auth.uid()))
  and exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='bursar')
))
with check ((select is_platform_developer()) or (
  school_id = (select p.school_id from public.profiles p where p.id=(select auth.uid()))
  and exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='bursar')
  and exists (select 1 from public.students s where s.id=student_fee_charges.student_id and s.school_id=student_fee_charges.school_id)
));

drop policy if exists "expenses_admin_bursar" on public.school_expenses;
drop policy if exists "expenses_bursar_only" on public.school_expenses;
create policy "expenses_bursar_only" on public.school_expenses for all to authenticated
using ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_expenses.school_id and p.role='bursar'))
with check ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_expenses.school_id and p.role='bursar'));

drop policy if exists "finance_ledger_school_scope" on public.school_financial_ledger;
drop policy if exists "finance_ledger_bursar_only" on public.school_financial_ledger;
create policy "finance_ledger_bursar_only" on public.school_financial_ledger for all to authenticated
using ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_financial_ledger.school_id and p.role='bursar'))
with check ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_financial_ledger.school_id and p.role='bursar'));

drop policy if exists "bank_accounts_school_scope" on public.school_bank_accounts;
drop policy if exists "bank_accounts_bursar_only" on public.school_bank_accounts;
create policy "bank_accounts_bursar_only" on public.school_bank_accounts for all to authenticated
using ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_bank_accounts.school_id and p.role='bursar'))
with check ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_bank_accounts.school_id and p.role='bursar'));

drop policy if exists "bank_transactions_school_scope" on public.school_bank_transactions;
drop policy if exists "bank_transactions_bursar_only" on public.school_bank_transactions;
create policy "bank_transactions_bursar_only" on public.school_bank_transactions for all to authenticated
using ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_bank_transactions.school_id and p.role='bursar'))
with check ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_bank_transactions.school_id and p.role='bursar'));

drop policy if exists "bursary_admin_bursar" on public.school_bursary_awards;
drop policy if exists "bursary_bursar_only" on public.school_bursary_awards;
create policy "bursary_bursar_only" on public.school_bursary_awards for all to authenticated
using ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_bursary_awards.school_id and p.role='bursar'))
with check ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_bursary_awards.school_id and p.role='bursar'));

drop policy if exists "suppliers_admin_bursar" on public.school_suppliers;
drop policy if exists "suppliers_bursar_only" on public.school_suppliers;
create policy "suppliers_bursar_only" on public.school_suppliers for all to authenticated
using ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_suppliers.school_id and p.role='bursar'))
with check ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_suppliers.school_id and p.role='bursar'));

drop policy if exists "purchase_orders_admin_bursar" on public.school_purchase_orders;
drop policy if exists "purchase_orders_bursar_only" on public.school_purchase_orders;
create policy "purchase_orders_bursar_only" on public.school_purchase_orders for all to authenticated
using ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_purchase_orders.school_id and p.role='bursar'))
with check ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_purchase_orders.school_id and p.role='bursar'));

drop policy if exists "supplier_invoices_admin_bursar" on public.school_supplier_invoices;
drop policy if exists "supplier_invoices_bursar_only" on public.school_supplier_invoices;
create policy "supplier_invoices_bursar_only" on public.school_supplier_invoices for all to authenticated
using ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_supplier_invoices.school_id and p.role='bursar'))
with check ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_supplier_invoices.school_id and p.role='bursar'));

drop policy if exists "payroll_school_scope" on public.school_payroll_records;
drop policy if exists "payroll_bursar_only" on public.school_payroll_records;
create policy "payroll_bursar_only" on public.school_payroll_records for all to authenticated
using ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_payroll_records.school_id and p.role='bursar'))
with check ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_payroll_records.school_id and p.role='bursar'));
