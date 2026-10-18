-- CBE/CBC RLS tuning: separate read/write policies and scope teachers to assigned class streams.
drop policy if exists cbe_portfolio_select on public.school_learning_portfolios;
drop policy if exists cbe_portfolio_write on public.school_learning_portfolios;
create policy cbe_portfolio_select on public.school_learning_portfolios for select to authenticated
using (
  exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_portfolios.school_id)
  and (
    exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('administrator','developer'))
    or exists (select 1 from public.profiles p join public.students s on s.school_id=p.school_id join public.teacher_assignments ta on ta.school_id=s.school_id and ta.teacher_id=p.id and ta.grade=s.grade and ta.stream=s.stream where p.id=(select auth.uid()) and p.role='teacher' and s.id=school_learning_portfolios.student_id)
    or exists (select 1 from public.student_account_links l where l.user_id=(select auth.uid()) and l.student_id=school_learning_portfolios.student_id and l.active=true)
  )
);
create policy cbe_portfolio_insert on public.school_learning_portfolios for insert to authenticated
with check (
  exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_portfolios.school_id and p.role='administrator')
  or (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_portfolios.school_id and p.role='teacher') and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learning_portfolios.student_id and s.school_id=school_learning_portfolios.school_id and ta.teacher_id=(select auth.uid())))
);
create policy cbe_portfolio_update on public.school_learning_portfolios for update to authenticated
using (
  exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_portfolios.school_id and p.role='administrator')
  or (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_portfolios.school_id and p.role='teacher') and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learning_portfolios.student_id and s.school_id=school_learning_portfolios.school_id and ta.teacher_id=(select auth.uid())))
)
with check (
  exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_portfolios.school_id and p.role='administrator')
  or (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_portfolios.school_id and p.role='teacher') and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learning_portfolios.student_id and s.school_id=school_learning_portfolios.school_id and ta.teacher_id=(select auth.uid())))
);
create policy cbe_portfolio_delete on public.school_learning_portfolios for delete to authenticated
using (
  exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_portfolios.school_id and p.role='administrator')
  or (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_portfolios.school_id and p.role='teacher') and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learning_portfolios.student_id and s.school_id=school_learning_portfolios.school_id and ta.teacher_id=(select auth.uid())))
);

drop policy if exists cbe_support_select on public.school_learning_support_plans;
drop policy if exists cbe_support_write on public.school_learning_support_plans;
create policy cbe_support_select on public.school_learning_support_plans for select to authenticated
using (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_support_plans.school_id)
 and (
  exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='administrator')
  or exists (select 1 from public.profiles p join public.students s on s.school_id=p.school_id join public.teacher_assignments ta on ta.school_id=s.school_id and ta.teacher_id=p.id and ta.grade=s.grade and ta.stream=s.stream where p.id=(select auth.uid()) and p.role='teacher' and s.id=school_learning_support_plans.student_id)
  or exists (select 1 from public.student_account_links l where l.user_id=(select auth.uid()) and l.student_id=school_learning_support_plans.student_id and l.active=true)
 )
);
create policy cbe_support_insert on public.school_learning_support_plans for insert to authenticated with check (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_support_plans.school_id and p.role='administrator')
 or (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_support_plans.school_id and p.role='teacher') and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learning_support_plans.student_id and s.school_id=school_learning_support_plans.school_id and ta.teacher_id=(select auth.uid())))
);
create policy cbe_support_update on public.school_learning_support_plans for update to authenticated using (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_support_plans.school_id and p.role='administrator')
 or (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_support_plans.school_id and p.role='teacher') and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learning_support_plans.student_id and s.school_id=school_learning_support_plans.school_id and ta.teacher_id=(select auth.uid())))
) with check (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_support_plans.school_id and p.role='administrator')
 or (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_support_plans.school_id and p.role='teacher') and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learning_support_plans.student_id and s.school_id=school_learning_support_plans.school_id and ta.teacher_id=(select auth.uid())))
);
create policy cbe_support_delete on public.school_learning_support_plans for delete to authenticated using (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_support_plans.school_id and p.role='administrator')
 or (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_support_plans.school_id and p.role='teacher') and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learning_support_plans.student_id and s.school_id=school_learning_support_plans.school_id and ta.teacher_id=(select auth.uid())))
);

drop policy if exists cbe_reflections_select on public.school_learning_reflections;
drop policy if exists cbe_reflections_write on public.school_learning_reflections;
create policy cbe_reflections_select on public.school_learning_reflections for select to authenticated
using (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_reflections.school_id)
 and (
  exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='administrator')
  or exists (select 1 from public.profiles p join public.students s on s.school_id=p.school_id join public.teacher_assignments ta on ta.school_id=s.school_id and ta.teacher_id=p.id and ta.grade=s.grade and ta.stream=s.stream where p.id=(select auth.uid()) and p.role='teacher' and s.id=school_learning_reflections.student_id)
  or exists (select 1 from public.student_account_links l where l.user_id=(select auth.uid()) and l.student_id=school_learning_reflections.student_id and l.active=true)
 )
);
create policy cbe_reflections_insert on public.school_learning_reflections for insert to authenticated with check (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_reflections.school_id and p.role='administrator')
 or (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_reflections.school_id and p.role='teacher') and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learning_reflections.student_id and s.school_id=school_learning_reflections.school_id and ta.teacher_id=(select auth.uid())))
);
create policy cbe_reflections_update on public.school_learning_reflections for update to authenticated using (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_reflections.school_id and p.role='administrator')
 or (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_reflections.school_id and p.role='teacher') and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learning_reflections.student_id and s.school_id=school_learning_reflections.school_id and ta.teacher_id=(select auth.uid())))
) with check (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_reflections.school_id and p.role='administrator')
 or (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_reflections.school_id and p.role='teacher') and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learning_reflections.student_id and s.school_id=school_learning_reflections.school_id and ta.teacher_id=(select auth.uid())))
);
create policy cbe_reflections_delete on public.school_learning_reflections for delete to authenticated using (
 exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_reflections.school_id and p.role='administrator')
 or (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_learning_reflections.school_id and p.role='teacher') and exists (select 1 from public.students s join public.teacher_assignments ta on ta.school_id=s.school_id and ta.grade=s.grade and ta.stream=s.stream where s.id=school_learning_reflections.student_id and s.school_id=school_learning_reflections.school_id and ta.teacher_id=(select auth.uid())))
);

drop policy if exists cbe_moderation_select on public.school_assessment_moderation;
drop policy if exists cbe_moderation_write on public.school_assessment_moderation;
create policy cbe_moderation_select on public.school_assessment_moderation for select to authenticated
using (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_assessment_moderation.school_id and p.role in ('administrator','teacher')));
create policy cbe_moderation_insert on public.school_assessment_moderation for insert to authenticated
with check (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_assessment_moderation.school_id and p.role='administrator'));
create policy cbe_moderation_update on public.school_assessment_moderation for update to authenticated
using (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_assessment_moderation.school_id and p.role='administrator'))
with check (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_assessment_moderation.school_id and p.role='administrator'));
create policy cbe_moderation_delete on public.school_assessment_moderation for delete to authenticated
using (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_assessment_moderation.school_id and p.role='administrator'));

create index if not exists school_learning_portfolios_student_id_idx on public.school_learning_portfolios(student_id);
create index if not exists school_learning_portfolios_recorded_by_idx on public.school_learning_portfolios(recorded_by);
create index if not exists school_learning_support_student_id_idx on public.school_learning_support_plans(student_id);
create index if not exists school_learning_support_created_by_idx on public.school_learning_support_plans(created_by);
create index if not exists school_learning_support_reviewed_by_idx on public.school_learning_support_plans(reviewed_by);
create index if not exists school_learning_reflections_student_id_idx on public.school_learning_reflections(student_id);
create index if not exists school_learning_reflections_recorded_by_idx on public.school_learning_reflections(recorded_by);
create index if not exists school_assessment_moderation_created_by_idx on public.school_assessment_moderation(created_by);
create index if not exists school_assessment_moderation_moderator_id_idx on public.school_assessment_moderation(moderator_id);
