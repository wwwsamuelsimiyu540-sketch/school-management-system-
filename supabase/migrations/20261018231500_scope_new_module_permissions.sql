-- Restrict timetable visibility to school administrators, assigned teachers, and linked learners/parents.
drop policy if exists timetable_read_school on public.school_timetable_entries;
create policy timetable_read_school on public.school_timetable_entries for select to authenticated using (
 exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_timetable_entries.school_id and (
  p.role='administrator'
  or (p.role='teacher' and (school_timetable_entries.teacher_id=p.id or exists(select 1 from public.teacher_assignments ta where ta.school_id=p.school_id and ta.teacher_id=p.id and ta.grade=school_timetable_entries.grade and ta.stream=school_timetable_entries.stream)))
  or exists(select 1 from public.student_account_links l join public.students st on st.id=l.student_id and st.school_id=l.school_id where l.school_id=school_timetable_entries.school_id and l.user_id=p.id and l.active and st.grade=school_timetable_entries.grade and st.stream=school_timetable_entries.stream)
 ))
);
-- Index foreign keys used by the new modules.
create index if not exists school_inventory_items_created_by_idx on public.school_inventory_items(created_by);
create index if not exists school_inventory_transactions_recorded_by_idx on public.school_inventory_transactions(recorded_by);
create index if not exists school_learning_assignments_teacher_idx on public.school_learning_assignments(teacher_id);
create index if not exists school_learning_submissions_student_fk_idx on public.school_learning_submissions(student_id);
create index if not exists school_learning_submissions_reviewed_by_idx on public.school_learning_submissions(reviewed_by);
create index if not exists school_messages_sender_idx on public.school_messages(sender_id);
create index if not exists school_messages_recipient_idx on public.school_messages(recipient_id);
create index if not exists school_timetable_entries_teacher_idx on public.school_timetable_entries(teacher_id);
create index if not exists school_timetable_entries_created_by_idx on public.school_timetable_entries(created_by);
-- Teachers can review only submissions for their own assignments or assigned classes.
drop policy if exists learning_submissions_read_school on public.school_learning_submissions;
create policy learning_submissions_read_school on public.school_learning_submissions for select to authenticated using (
 exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_submissions.school_id and (
  p.role='administrator'
  or (p.role='teacher' and exists(select 1 from public.school_learning_assignments a where a.id=school_learning_submissions.assignment_id and a.school_id=p.school_id and (
    a.teacher_id=p.id or exists(select 1 from public.teacher_assignments ta where ta.school_id=p.school_id and ta.teacher_id=p.id and ta.grade=a.grade and (a.stream is null or ta.stream=a.stream))
  )))
  or exists(select 1 from public.student_account_links l where l.school_id=school_learning_submissions.school_id and l.student_id=school_learning_submissions.student_id and l.user_id=p.id and l.active)
 ))
);
drop policy if exists learning_submissions_write_school on public.school_learning_submissions;
create policy learning_submissions_write_school on public.school_learning_submissions for all to authenticated
using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_submissions.school_id and (
 p.role='administrator'
 or (p.role='teacher' and exists(select 1 from public.school_learning_assignments a where a.id=school_learning_submissions.assignment_id and a.school_id=p.school_id and a.teacher_id=p.id))
 or (p.role='student' and exists(select 1 from public.student_account_links l where l.school_id=school_learning_submissions.school_id and l.student_id=school_learning_submissions.student_id and l.user_id=p.id and l.active))
)))
with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_submissions.school_id and (
 p.role='administrator'
 or (p.role='teacher' and exists(select 1 from public.school_learning_assignments a where a.id=school_learning_submissions.assignment_id and a.school_id=p.school_id and a.teacher_id=p.id))
 or (p.role='student' and exists(select 1 from public.student_account_links l where l.school_id=school_learning_submissions.school_id and l.student_id=school_learning_submissions.student_id and l.user_id=p.id and l.active))
)));