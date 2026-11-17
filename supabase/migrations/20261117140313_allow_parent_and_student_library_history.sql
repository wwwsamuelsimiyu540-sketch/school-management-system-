drop policy if exists "library_loans_school_read" on public.school_library_loans;
create policy "library_loans_school_read" on public.school_library_loans
for select to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.school_id = school_library_loans.school_id
      and p.role in ('librarian','administrator')
  )
  or exists (
    select 1 from public.student_account_links l
    where l.student_id = school_library_loans.student_id
      and l.user_id = (select auth.uid())
      and l.school_id = school_library_loans.school_id
      and l.active = true
      and l.relationship in ('student','parent','guardian')
  )
);
